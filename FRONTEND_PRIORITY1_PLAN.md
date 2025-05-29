# Frontend Priority 1 Implementation Plan

## Goal
Show Pinecone connection status for speakers and allow manual linking/unlinking.

## API Endpoints You'll Use

### GET `/api/speakers`
**Returns:** Speaker list with new `pinecone_speaker_name` field
```json
{
  "id": "uuid",
  "name": "John Doe", 
  "pinecone_speaker_name": "john_doe" // or null if not linked
}
```

### GET `/api/pinecone/speakers`
**Returns:** List of available Pinecone speaker names
```json
[
  "john_doe",
  "jane_smith", 
  "bob_wilson",
  "alice_johnson"
]
```

### PUT `/api/speakers/{speaker_id}/link-pinecone`
**Body:** `{"pinecone_speaker_name": "existing_pinecone_speaker"}`
**Purpose:** Link database speaker to existing Pinecone speaker

### DELETE `/api/speakers/{speaker_id}/unlink-pinecone`
**Purpose:** Remove link between database speaker and Pinecone speaker

## iOS Changes Needed

### 1. Update DataModels.swift
Add `pinecone_speaker_name` to Speaker struct

### 2. Update SpeakersListView.swift  
- Show ✅ icon for linked speakers
- Show ⚪ icon for unlinked speakers
- Add "Link to Pinecone" button for unlinked speakers
- Add "Unlink" button for linked speakers

### 3. Update SpeakerIDService.swift
Add methods for linking/unlinking

### 4. Test Flow
1. View speaker list - see connection status
2. Link unlinked speaker to Pinecone speaker
3. Verify link appears in UI
4. Unlink speaker
5. Verify link removed from UI

## Expected UI Result
```
✅ John Doe (linked to: john_doe)     [Unlink]
⚪ Jane Smith                         [Link to Pinecone]
✅ Bob Wilson (linked to: bob_w)      [Unlink]
``` 