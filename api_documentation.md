# Speaker ID Server API Documentation

This document provides detailed information about each API endpoint in the Speaker ID Server application. The API is organized into three main sections:

1. Dashboard Management - Endpoints for managing conversations and audio files
2. Speaker Management - Endpoints for managing speaker profiles and utterances
3. Pinecone Management - Endpoints for managing speaker embeddings in Pinecone

## Dashboard Management Endpoints

### Get Root Page

Returns the main HTML page of the application.

- **URL**: `/`
- **Method**: `GET`
- **Response Format**: HTML
- **Description**: Serves the main dashboard interface from the static directory.
- **Error Responses**: None specific to this endpoint.
- **Authentication**: None required.

### List All Conversations

Retrieves a list of all conversations stored in the database.

- **URL**: `/api/conversations`
- **Method**: `GET`
- **Response Format**: JSON array of conversation objects
- **Response Fields**:
  - `id`: Unique identifier for the conversation
  - `conversation_id`: String identifier for the conversation
  - `created_at`: ISO-formatted timestamp of when the conversation was processed
  - `duration`: Duration of the conversation in seconds
  - `display_name`: Optional display name for the conversation (if column exists)
  - `speaker_count`: Number of unique speakers in the conversation
  - `utterance_count`: Total number of utterances in the conversation
  - `speakers`: Array of speaker names in the conversation
- **Error Responses**: 
  - `500 Internal Server Error`: If there's an issue connecting to the database or processing the request
- **Authentication**: None required.

### Get Conversation Details

Retrieves detailed information about a specific conversation, including all utterances.

- **URL**: `/api/conversations/{conversation_id}`
- **Method**: `GET`
- **URL Parameters**:
  - `conversation_id`: ID of the conversation to retrieve
- **Response Format**: JSON object with conversation details
- **Response Fields**:
  - `id`: Unique identifier for the conversation
  - `conversation_id`: String identifier for the conversation
  - `display_name`: Optional display name for the conversation
  - `date_processed`: ISO-formatted timestamp of when the conversation was processed
  - `duration_seconds`: Duration of the conversation in seconds
  - `utterances`: Array of utterance objects with the following fields:
    - `id`: Unique identifier for the utterance
    - `speaker_id`: ID of the speaker
    - `speaker_name`: Name of the speaker
    - `start_time`: Start time of the utterance
    - `end_time`: End time of the utterance
    - `start_ms`: Start time in milliseconds
    - `end_ms`: End time in milliseconds
    - `text`: Transcribed text of the utterance
    - `audio_url`: URL to access the audio for this utterance
- **Error Responses**:
  - `404 Not Found`: If the conversation is not found
  - `500 Internal Server Error`: If there's an issue processing the request
- **Authentication**: None required.

### Get Utterance Audio

Retrieves the audio file for a specific utterance.

- **URL**: `/api/audio/{conversation_id}/{utterance_id}`
- **Method**: `GET`
- **URL Parameters**:
  - `conversation_id`: ID of the conversation
  - `utterance_id`: ID of the utterance
- **Response Format**: Audio file (WAV) or redirect to a presigned S3 URL
- **Description**: Returns the audio file for the specified utterance. If the file is stored in S3, the response will be a redirect to a presigned URL.
- **Error Responses**:
  - `404 Not Found`: If the conversation, utterance, or audio file is not found
  - `500 Internal Server Error`: If there's an issue processing the request
- **Authentication**: None required.

### Upload Conversation

Uploads and processes a new audio conversation.

- **URL**: `/api/conversations/upload`
- **Method**: `POST`
- **Request Format**: Multipart form data
- **Request Parameters**:
  - `file`: Audio file to upload (required)
  - `display_name`: Optional display name for the conversation
  - `match_threshold`: Threshold for speaker matching (default: 0.40)
  - `auto_update_threshold`: Threshold for auto-updating speaker profiles (default: 0.50)
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the upload was successful
  - `conversation_id`: ID of the newly created conversation
  - `message`: Status message
- **Error Responses**:
  - `500 Internal Server Error`: If there's an issue processing the audio file
- **Authentication**: None required.

### Update Conversation

Updates the display name of a conversation.

- **URL**: `/api/conversations/{conversation_id}`
- **Method**: `PUT`
- **URL Parameters**:
  - `conversation_id`: ID of the conversation to update
- **Request Format**: Form data
- **Request Parameters**:
  - `display_name`: New display name for the conversation (required)
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the update was successful
  - `id`: ID of the updated conversation
  - `display_name`: New display name
- **Error Responses**:
  - `404 Not Found`: If the conversation is not found
  - `500 Internal Server Error`: If there's an issue updating the conversation
- **Authentication**: None required.

### Delete Conversation

Deletes a conversation and all associated utterances and files.

- **URL**: `/api/conversations/{conversation_id}`
- **Method**: `DELETE`
- **URL Parameters**:
  - `conversation_id`: ID of the conversation to delete
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the deletion was successful
  - `id`: ID of the deleted conversation
- **Error Responses**:
  - `404 Not Found`: If the conversation is not found
  - `500 Internal Server Error`: If there's an issue deleting the conversation
- **Authentication**: None required.

## Speaker Management Endpoints

### Get All Speakers

Retrieves a list of all speakers in the database.

- **URL**: `/api/speakers`
- **Method**: `GET`
- **Response Format**: JSON array of speaker objects
- **Response Fields**:
  - `id`: Unique identifier for the speaker
  - `name`: Name of the speaker
  - `utterance_count`: Number of utterances by this speaker
  - `total_duration`: Total duration of all utterances by this speaker in milliseconds
- **Error Responses**:
  - `500 Internal Server Error`: If there's an issue connecting to the database or processing the request
- **Authentication**: None required.

### Add Speaker

Adds a new speaker to the database.

- **URL**: `/api/speakers`
- **Method**: `POST`
- **Request Format**: Form data
- **Request Parameters**:
  - `name`: Name of the new speaker (required)
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the addition was successful
  - `id`: ID of the newly created speaker
  - `name`: Name of the speaker
- **Error Responses**:
  - `500 Internal Server Error`: If there's an issue adding the speaker
- **Authentication**: None required.

### Update Speaker

Updates a speaker's name.

- **URL**: `/api/speakers/{speaker_id}`
- **Method**: `PUT`
- **URL Parameters**:
  - `speaker_id`: ID of the speaker to update
- **Request Format**: Form data
- **Request Parameters**:
  - `name`: New name for the speaker (required)
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the update was successful
  - `id`: ID of the updated speaker
  - `name`: New name of the speaker
- **Error Responses**:
  - `404 Not Found`: If the speaker is not found
  - `500 Internal Server Error`: If there's an issue updating the speaker
- **Authentication**: None required.

### Get Speaker Details

Retrieves detailed information about a specific speaker.

- **URL**: `/api/speakers/{speaker_id}/details`
- **Method**: `GET`
- **URL Parameters**:
  - `speaker_id`: ID of the speaker to retrieve
- **Response Format**: JSON object
- **Response Fields**:
  - `id`: Unique identifier for the speaker
  - `name`: Name of the speaker
  - `utterance_count`: Number of utterances by this speaker
  - `total_duration`: Total duration of all utterances by this speaker in milliseconds
  - `avg_duration`: Average duration of utterances by this speaker in milliseconds
  - `recent_utterances`: Array of recent utterance objects with the following fields:
    - `text`: Transcribed text of the utterance
    - `start_time`: Start time of the utterance in milliseconds
    - `end_time`: End time of the utterance in milliseconds
    - `conversation_name`: Name of the conversation
    - `conversation_id`: ID of the conversation
- **Error Responses**:
  - `404 Not Found`: If the speaker is not found
  - `500 Internal Server Error`: If there's an issue processing the request
- **Authentication**: None required.

### Update Utterance

Updates the speaker ID or text of an utterance.

- **URL**: `/api/utterances/{utterance_id}`
- **Method**: `PUT`
- **URL Parameters**:
  - `utterance_id`: ID of the utterance to update
- **Request Format**: JSON object
- **Request Parameters**:
  - `speaker_id`: (Optional) New speaker ID for the utterance
  - `text`: (Optional) New transcribed text for the utterance
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the update was successful
  - `id`: ID of the updated utterance
  - `speaker_id`: Speaker ID of the utterance
  - `text`: Transcribed text of the utterance
  - `conversation_id`: ID of the conversation
- **Error Responses**:
  - `400 Bad Request`: If neither speaker_id nor text is provided
  - `404 Not Found`: If the utterance or speaker is not found
  - `500 Internal Server Error`: If there's an issue updating the utterance
- **Authentication**: None required.

### Update All Utterances for a Speaker

Updates all utterances from one speaker to another.

- **URL**: `/api/speakers/{from_speaker_id}/update-all-utterances`
- **Method**: `PUT`
- **URL Parameters**:
  - `from_speaker_id`: ID of the source speaker
- **Request Format**: Form data
- **Request Parameters**:
  - `to_speaker_id`: ID of the target speaker (required)
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the update was successful
  - `from_speaker_id`: ID of the source speaker
  - `to_speaker_id`: ID of the target speaker
  - `updated_count`: Number of utterances updated
- **Error Responses**:
  - `404 Not Found`: If either speaker is not found
  - `500 Internal Server Error`: If there's an issue updating the utterances
- **Authentication**: None required.

### Delete Speaker

Deletes a speaker from the database.

- **URL**: `/api/speakers/{speaker_id}`
- **Method**: `DELETE`
- **URL Parameters**:
  - `speaker_id`: ID of the speaker to delete
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the deletion was successful
  - `id`: ID of the deleted speaker
  - `name`: Name of the deleted speaker
- **Error Responses**:
  - `404 Not Found`: If the speaker is not found
  - `500 Internal Server Error`: If there's an issue deleting the speaker
- **Authentication**: None required.

## Pinecone Management Endpoints

### Get Pinecone Speakers

Retrieves all speakers and their embeddings from Pinecone.

- **URL**: `/api/pinecone/speakers`
- **Method**: `GET`
- **Response Format**: JSON object
- **Response Fields**:
  - `speakers`: Array of speaker objects with the following fields:
    - `name`: Name of the speaker
    - `embeddings`: Array of embedding objects with the following fields:
      - `id`: Unique identifier for the embedding
- **Error Responses**:
  - `500 Internal Server Error`: If Pinecone is not initialized or there's an issue processing the request
- **Authentication**: None required.

### Add Pinecone Speaker

Adds a new speaker with an embedding to Pinecone.

- **URL**: `/api/pinecone/speakers`
- **Method**: `POST`
- **Request Format**: Multipart form data
- **Request Parameters**:
  - `speaker_name`: Name of the new speaker (required)
  - `audio_file`: Audio file to generate the embedding from (required)
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the addition was successful
  - `speaker_name`: Name of the speaker
  - `embedding_id`: ID of the newly created embedding
- **Error Responses**:
  - `400 Bad Request`: If the speaker already exists
  - `500 Internal Server Error`: If Pinecone is not initialized or there's an issue processing the request
- **Authentication**: None required.

### Add Pinecone Embedding

Adds an additional embedding to an existing speaker in Pinecone.

- **URL**: `/api/pinecone/embeddings`
- **Method**: `POST`
- **Request Format**: Multipart form data
- **Request Parameters**:
  - `speaker_name`: Name of the existing speaker (required)
  - `audio_file`: Audio file to generate the embedding from (required)
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the addition was successful
  - `speaker_name`: Name of the speaker
  - `embedding_id`: ID of the newly created embedding
- **Error Responses**:
  - `400 Bad Request`: If the speaker does not exist
  - `500 Internal Server Error`: If Pinecone is not initialized or there's an issue processing the request
- **Authentication**: None required.

### Delete Pinecone Speaker

Deletes all embeddings for a speaker from Pinecone.

- **URL**: `/api/pinecone/speakers/{speaker_name}`
- **Method**: `DELETE`
- **URL Parameters**:
  - `speaker_name`: Name of the speaker to delete
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the deletion was successful
  - `speaker_name`: Name of the deleted speaker
  - `embeddings_deleted`: Number of embeddings deleted
- **Error Responses**:
  - `404 Not Found`: If no embeddings are found for the speaker
  - `500 Internal Server Error`: If Pinecone is not initialized or there's an issue processing the request
- **Authentication**: None required.

### Delete Pinecone Embedding

Deletes a specific embedding from Pinecone.

- **URL**: `/api/pinecone/embeddings/{embedding_id}`
- **Method**: `DELETE`
- **URL Parameters**:
  - `embedding_id`: ID of the embedding to delete
- **Response Format**: JSON object
- **Response Fields**:
  - `success`: Boolean indicating if the deletion was successful
  - `embedding_id`: ID of the deleted embedding
  - `speaker_name`: Name of the speaker the embedding belonged to
- **Error Responses**:
  - `404 Not Found`: If the embedding is not found
  - `500 Internal Server Error`: If Pinecone is not initialized or there's an issue processing the request
- **Authentication**: None required.

## Health Check Endpoint

### Health Check

Checks if the API is running.

- **URL**: `/health`
- **Method**: `GET`
- **Response Format**: JSON object
- **Response Fields**:
  - `status`: Status of the API ("healthy")
  - `message`: Status message
- **Error Responses**: None specific to this endpoint.
- **Authentication**: None required.
