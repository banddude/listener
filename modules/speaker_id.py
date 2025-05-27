def process_conversation(file_path, conversation_id=None, display_name=None, match_threshold=MATCH_THRESHOLD, auto_update_threshold=AUTO_UPDATE_CONFIDENCE_THRESHOLD):
    """Process an audio file and identify speakers"""
    print(f"\n🎙 Processing conversation: {file_path}")
    
    # Create conversation ID if not provided
    if not conversation_id:
        conversation_id = f"convo_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
    # Convert to WAV if needed
    wav_file = convert_to_wav(file_path)
    
    # Load audio file for processing
    full_audio = AudioSegment.from_wav(wav_file)
    
    # Transcribe audio using AssemblyAI
    transcript_data = transcribe(wav_file)
    
    # Extract utterances with speaker labels
    utterances = transcript_data.get('utterances', [])
    
    try:
        # Add conversation to database
        conversation_info = {
            'conversation_id': conversation_id,
            'original_audio': os.path.basename(file_path),
            'duration_seconds': len(full_audio) / 1000.0,
            'display_name': display_name
        }
        db_conversation_id = add_conversation(conversation_info)
        print(f"✅ Added conversation to database with ID: {db_conversation_id}")
        
        # Process utterances and store in S3/database
        utterance_metadata = []
        for i, utterance in enumerate(utterances):
            if "words" not in utterance:
                continue
            
            # Extract audio segment
            start_ms = int(utterance["start"])
            end_ms = int(utterance["end"])
            duration_ms = end_ms - start_ms
            
            # Only process if duration is sufficient
            if duration_ms < 700:  # Skip very short utterances
                print(f"  Skipping short utterance ({duration_ms}ms)")
                continue
                
            audio_segment = full_audio[start_ms:end_ms]
            
            # Test the segment
            speaker_name, confidence, embedding_id, embedding = test_voice_segment(
                audio_segment, conversation_id, i, match_threshold
            )
            
            # If no speaker found, use AssemblyAI's label
            if not speaker_name:
                speaker_name = f"Speaker_{utterance['speaker']}"
                confidence = utterance.get("confidence", 0.0)
            
            # Add speaker to database if new
            speaker_id = add_speaker(speaker_name)
            
            # Store metadata
            utterance_data = {
                "id": i,
                "start_ms": start_ms,
                "end_ms": end_ms,
                "start_time": format_time(start_ms),
                "end_time": format_time(end_ms),
                "text": utterance["text"],
                "confidence": confidence,
                "speaker": speaker_name,
                "embedding_id": embedding_id,
                "words": utterance["words"],  # Include word-level data
                "conversation_id": db_conversation_id  # Use the database ID, not the string ID
            }
            utterance_metadata.append(utterance_data)
            
            # Auto-update Pinecone with high-confidence embeddings
            if embedding is not None and confidence > auto_update_threshold:
                # Generate source info for metadata
                source_info = f"{S3_BASE_PATH}/{conversation_id}/{S3_UTTERANCES_PATH}/utterance_{i:03d}.wav"
                # Try to auto-update the database
                auto_update_embedding(
                    embedding_np=embedding, 
                    speaker_name=speaker_name, 
                    audio_source=source_info,
                    index=index,
                    confidence=confidence,
                    threshold=auto_update_threshold
                )
            
            # Add utterance to database - FIXED: Use db_conversation_id (UUID) for proper relationship
            s3_path = f"{S3_BASE_PATH}/{conversation_id}/{S3_UTTERANCES_PATH}/utterance_{i:03d}.wav"
            add_utterance(utterance_info={
                'utterance_id': f"utterance_{uuid.uuid4().hex[:8]}",
                'start_time': format_time(start_ms),
                'end_time': format_time(end_ms),
                'start_ms': start_ms,
                'end_ms': end_ms,
                'text': utterance["text"],
                'confidence': confidence,
                'embedding_id': embedding_id,
                'audio_file': s3_path,
                'speaker_id': speaker_id,
                'speaker': speaker_name,
                'conversation_id': db_conversation_id,  # FIXED: Use the database UUID, not string
                'words': utterance["words"]  # Include word-level data
            })
        
        # Try to identify unknown speakers by combining their utterances
        utterance_metadata = identify_unknown_speakers_by_combining(
            utterance_metadata,
            {"conversation_id": conversation_id},
            full_audio,
            match_threshold,
            auto_update_threshold
        )
        
        print(f"✅ Successfully processed {len(utterance_metadata)} utterances for conversation {conversation_id}")
        
        return {
            "conversation_id": conversation_id,
            "original_file": os.path.basename(file_path),
            "s3_path": s3_path,
            "utterances": utterance_metadata,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"Error processing conversation: {str(e)}")
        import traceback
        traceback.print_exc()
        return None
    finally:
        # Clean up temporary WAV file if it was created
        if wav_file != file_path and os.path.exists(wav_file):
            os.remove(wav_file)
            print(f"Removed temporary file: {wav_file}") 