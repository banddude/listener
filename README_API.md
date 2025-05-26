# Speaker ID Server API Integration Guide

## Introduction

The Speaker ID Server is a robust application designed for speaker identification and diarization in audio conversations. This document provides comprehensive guidance on how to integrate with the Speaker ID Server's backend API in your own applications. The API allows you to upload audio conversations, manage speakers, retrieve conversation details, and work with speaker embeddings for voice recognition.

The system is built on FastAPI and provides endpoints for three main functional areas:

1. **Dashboard Management** - Endpoints for managing conversations and audio files
2. **Speaker Management** - Endpoints for managing speaker profiles and utterances
3. **Pinecone Management** - Endpoints for managing speaker embeddings in Pinecone

This guide is based on the actual implementation in the codebase, ensuring you have the most accurate and up-to-date information for integration.

## Installation Requirements

To integrate with the Speaker ID Server API, you'll need to ensure your environment meets the following requirements:

### Dependencies

The Speaker ID Server relies on several key dependencies:

- **FastAPI** - The web framework used for the API
- **Pinecone** - Vector database for storing and querying speaker embeddings
- **PostgreSQL** - Relational database for storing conversation and speaker data
- **AWS S3** - Storage for audio files
- **pydub** - Audio processing library

### Environment Variables

The following environment variables should be configured:

- `PINECONE_API_KEY` - API key for Pinecone vector database
- `DATABASE_URL` - PostgreSQL connection string
- `AWS_ACCESS_KEY_ID` - AWS access key for S3 storage
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for S3 storage
- `S3_BUCKET_NAME` - Name of the S3 bucket for storing audio files

### Setting Up Your Own Instance

If you want to run your own instance of the Speaker ID Server:

1. Clone the repository: `git clone https://github.com/banddude/speaker-id-server.git`
2. Install dependencies: `pip install -r requirements.txt`
3. Set up the required environment variables
4. Initialize the database using the schema in `modules/database/schema.sql`
5. Start the server: `python app.py`

## API Integration

### Base URL

When integrating with the hosted instance, use the following base URL:

```
https://speaker-id-server-production.up.railway.app
```

For local development, the default URL is:

```
http://localhost:8003
```

### Authentication

The current implementation does not include authentication. All endpoints are publicly accessible. If you're integrating this into a production environment, you should implement your own authentication layer.

### Error Handling

The API uses standard HTTP status codes to indicate the success or failure of requests:

- `200 OK` - The request was successful
- `201 Created` - A new resource was successfully created
- `400 Bad Request` - The request was malformed or invalid
- `404 Not Found` - The requested resource was not found
- `500 Internal Server Error` - An error occurred on the server

Error responses include a JSON object with a `detail` field containing an error message:

```json
{
  "detail": "Error message describing what went wrong"
}
```

For more detailed error information, some endpoints may return additional fields in the error response.

## API Endpoints

### Dashboard Management

#### List All Conversations

Retrieves a list of all conversations stored in the database.

**Request:**
```
GET /api/conversations
```

**Response:**
```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "conversation_id": "conv_12345",
    "created_at": "2023-01-01T12:00:00.000Z",
    "duration": 300,
    "display_name": "Meeting with Team",
    "speaker_count": 3,
    "utterance_count": 25,
    "speakers": ["John", "Alice", "Bob"]
  },
  ...
]
```

**Integration Example:**
```javascript
async function getConversations() {
  const response = await fetch('https://speaker-id-server-production.up.railway.app/api/conversations');
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  return await response.json();
}
```

#### Get Conversation Details

Retrieves detailed information about a specific conversation, including all utterances.

**Request:**
```
GET /api/conversations/{conversation_id}
```

**Response:**
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "conversation_id": "conv_12345",
  "display_name": "Meeting with Team",
  "date_processed": "2023-01-01T12:00:00.000Z",
  "duration_seconds": 300,
  "utterances": [
    {
      "id": "utterance_001",
      "speaker_id": "speaker_123",
      "speaker_name": "John",
      "start_time": "00:00:10",
      "end_time": "00:00:15",
      "start_ms": 10000,
      "end_ms": 15000,
      "text": "Hello everyone, shall we begin?",
      "audio_url": "/api/audio/123e4567-e89b-12d3-a456-426614174000/utterance_001"
    },
    ...
  ]
}
```

**Integration Example:**
```javascript
async function getConversationDetails(conversationId) {
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/conversations/${conversationId}`);
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  return await response.json();
}
```

#### Get Utterance Audio

Retrieves the audio file for a specific utterance.

**Request:**
```
GET /api/audio/{conversation_id}/{utterance_id}
```

**Response:**
The endpoint returns either the audio file directly or redirects to a presigned S3 URL where the audio file can be accessed.

**Integration Example:**
```javascript
function getUtteranceAudioUrl(conversationId, utteranceId) {
  return `https://speaker-id-server-production.up.railway.app/api/audio/${conversationId}/${utteranceId}`;
}

// In an audio player:
const audioElement = document.createElement('audio');
audioElement.src = getUtteranceAudioUrl('123e4567-e89b-12d3-a456-426614174000', 'utterance_001');
audioElement.controls = true;
document.body.appendChild(audioElement);
```

#### Upload Conversation

Uploads and processes a new audio conversation.

**Request:**
```
POST /api/conversations/upload
Content-Type: multipart/form-data

file: [audio file]
display_name: Meeting with Team (optional)
match_threshold: 0.40 (optional)
auto_update_threshold: 0.50 (optional)
```

**Response:**
```json
{
  "success": true,
  "conversation_id": "123e4567-e89b-12d3-a456-426614174000",
  "message": "Conversation processed successfully"
}
```

**Integration Example:**
```javascript
async function uploadConversation(audioFile, displayName) {
  const formData = new FormData();
  formData.append('file', audioFile);
  if (displayName) {
    formData.append('display_name', displayName);
  }
  
  const response = await fetch('https://speaker-id-server-production.up.railway.app/api/conversations/upload', {
    method: 'POST',
    body: formData
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Update Conversation

Updates the display name of a conversation.

**Request:**
```
PUT /api/conversations/{conversation_id}
Content-Type: application/x-www-form-urlencoded

display_name=Updated Meeting Name
```

**Response:**
```json
{
  "success": true,
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "display_name": "Updated Meeting Name"
}
```

**Integration Example:**
```javascript
async function updateConversationName(conversationId, newName) {
  const formData = new FormData();
  formData.append('display_name', newName);
  
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/conversations/${conversationId}`, {
    method: 'PUT',
    body: formData
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Delete Conversation

Deletes a conversation and all associated utterances and files.

**Request:**
```
DELETE /api/conversations/{conversation_id}
```

**Response:**
```json
{
  "success": true,
  "id": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Integration Example:**
```javascript
async function deleteConversation(conversationId) {
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/conversations/${conversationId}`, {
    method: 'DELETE'
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

### Speaker Management

#### Get All Speakers

Retrieves a list of all speakers in the database.

**Request:**
```
GET /api/speakers
```

**Response:**
```json
[
  {
    "id": "speaker_123",
    "name": "John",
    "utterance_count": 15,
    "total_duration": 45000
  },
  ...
]
```

**Integration Example:**
```javascript
async function getSpeakers() {
  const response = await fetch('https://speaker-id-server-production.up.railway.app/api/speakers');
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  return await response.json();
}
```

#### Add Speaker

Adds a new speaker to the database.

**Request:**
```
POST /api/speakers
Content-Type: application/x-www-form-urlencoded

name=New Speaker
```

**Response:**
```json
{
  "success": true,
  "id": "speaker_456",
  "name": "New Speaker"
}
```

**Integration Example:**
```javascript
async function addSpeaker(speakerName) {
  const formData = new FormData();
  formData.append('name', speakerName);
  
  const response = await fetch('https://speaker-id-server-production.up.railway.app/api/speakers', {
    method: 'POST',
    body: formData
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Update Speaker

Updates a speaker's name.

**Request:**
```
PUT /api/speakers/{speaker_id}
Content-Type: application/x-www-form-urlencoded

name=Updated Speaker Name
```

**Response:**
```json
{
  "success": true,
  "id": "speaker_123",
  "name": "Updated Speaker Name"
}
```

**Integration Example:**
```javascript
async function updateSpeakerName(speakerId, newName) {
  const formData = new FormData();
  formData.append('name', newName);
  
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/speakers/${speakerId}`, {
    method: 'PUT',
    body: formData
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Get Speaker Details

Retrieves detailed information about a specific speaker.

**Request:**
```
GET /api/speakers/{speaker_id}/details
```

**Response:**
```json
{
  "id": "speaker_123",
  "name": "John",
  "utterance_count": 15,
  "total_duration": 45000,
  "avg_duration": 3000,
  "recent_utterances": [
    {
      "text": "Hello everyone, shall we begin?",
      "start_time": 10000,
      "end_time": 15000,
      "conversation_name": "Meeting with Team",
      "conversation_id": "conv_12345"
    },
    ...
  ]
}
```

**Integration Example:**
```javascript
async function getSpeakerDetails(speakerId) {
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/speakers/${speakerId}/details`);
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  return await response.json();
}
```

#### Update Utterance

Updates the speaker ID or text of an utterance.

**Request:**
```
PUT /api/utterances/{utterance_id}
Content-Type: application/json

{
  "speaker_id": "speaker_456",
  "text": "Updated transcription text"
}
```

**Response:**
```json
{
  "success": true,
  "id": "utterance_001",
  "speaker_id": "speaker_456",
  "text": "Updated transcription text",
  "conversation_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Integration Example:**
```javascript
async function updateUtterance(utteranceId, updates) {
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/utterances/${utteranceId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(updates)
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Update All Utterances for a Speaker

Updates all utterances from one speaker to another.

**Request:**
```
PUT /api/speakers/{from_speaker_id}/update-all-utterances
Content-Type: application/x-www-form-urlencoded

to_speaker_id=speaker_456
```

**Response:**
```json
{
  "success": true,
  "from_speaker_id": "speaker_123",
  "to_speaker_id": "speaker_456",
  "updated_count": 15
}
```

**Integration Example:**
```javascript
async function updateAllUtterances(fromSpeakerId, toSpeakerId) {
  const formData = new FormData();
  formData.append('to_speaker_id', toSpeakerId);
  
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/speakers/${fromSpeakerId}/update-all-utterances`, {
    method: 'PUT',
    body: formData
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Delete Speaker

Deletes a speaker from the database.

**Request:**
```
DELETE /api/speakers/{speaker_id}
```

**Response:**
```json
{
  "success": true,
  "id": "speaker_123",
  "name": "John"
}
```

**Integration Example:**
```javascript
async function deleteSpeaker(speakerId) {
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/speakers/${speakerId}`, {
    method: 'DELETE'
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

### Pinecone Management

#### Get Pinecone Speakers

Retrieves all speakers and their embeddings from Pinecone.

**Request:**
```
GET /api/pinecone/speakers
```

**Response:**
```json
{
  "speakers": [
    {
      "name": "John",
      "embeddings": [
        {
          "id": "speaker_John_12345678"
        },
        ...
      ]
    },
    ...
  ]
}
```

**Integration Example:**
```javascript
async function getPineconeSpeakers() {
  const response = await fetch('https://speaker-id-server-production.up.railway.app/api/pinecone/speakers');
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  return await response.json();
}
```

#### Add Pinecone Speaker

Adds a new speaker with an embedding to Pinecone.

**Request:**
```
POST /api/pinecone/speakers
Content-Type: multipart/form-data

speaker_name=New Speaker
audio_file=[audio file]
```

**Response:**
```json
{
  "success": true,
  "speaker_name": "New Speaker",
  "embedding_id": "speaker_New Speaker_12345678"
}
```

**Integration Example:**
```javascript
async function addPineconeSpeaker(speakerName, audioFile) {
  const formData = new FormData();
  formData.append('speaker_name', speakerName);
  formData.append('audio_file', audioFile);
  
  const response = await fetch('https://speaker-id-server-production.up.railway.app/api/pinecone/speakers', {
    method: 'POST',
    body: formData
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Add Pinecone Embedding

Adds an additional embedding to an existing speaker in Pinecone.

**Request:**
```
POST /api/pinecone/embeddings
Content-Type: multipart/form-data

speaker_name=Existing Speaker
audio_file=[audio file]
```

**Response:**
```json
{
  "success": true,
  "speaker_name": "Existing Speaker",
  "embedding_id": "speaker_Existing Speaker_87654321"
}
```

**Integration Example:**
```javascript
async function addPineconeEmbedding(speakerName, audioFile) {
  const formData = new FormData();
  formData.append('speaker_name', speakerName);
  formData.append('audio_file', audioFile);
  
  const response = await fetch('https://speaker-id-server-production.up.railway.app/api/pinecone/embeddings', {
    method: 'POST',
    body: formData
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Delete Pinecone Speaker

Deletes all embeddings for a speaker from Pinecone.

**Request:**
```
DELETE /api/pinecone/speakers/{speaker_name}
```

**Response:**
```json
{
  "success": true,
  "speaker_name": "John",
  "embeddings_deleted": 3
}
```

**Integration Example:**
```javascript
async function deletePineconeSpeaker(speakerName) {
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/pinecone/speakers/${speakerName}`, {
    method: 'DELETE'
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

#### Delete Pinecone Embedding

Deletes a specific embedding from Pinecone.

**Request:**
```
DELETE /api/pinecone/embeddings/{embedding_id}
```

**Response:**
```json
{
  "success": true,
  "embedding_id": "speaker_John_12345678",
  "speaker_name": "John"
}
```

**Integration Example:**
```javascript
async function deletePineconeEmbedding(embeddingId) {
  const response = await fetch(`https://speaker-id-server-production.up.railway.app/api/pinecone/embeddings/${embeddingId}`, {
    method: 'DELETE'
  });
  
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  
  return await response.json();
}
```

### Health Check

#### Health Check

Checks if the API is running.

**Request:**
```
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "message": "Speaker ID API is running"
}
```

**Integration Example:**
```javascript
async function checkApiHealth() {
  const response = await fetch('https://speaker-id-server-production.up.railway.app/health');
  if (!response.ok) {
    throw new Error(`Error: ${response.status}`);
  }
  return await response.json();
}
```

## Integration Best Practices

### Error Handling

When integrating with the Speaker ID Server API, implement robust error handling to manage various error scenarios:

```javascript
async function apiRequest(url, options = {}) {
  try {
    const response = await fetch(url, options);
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.detail || `API error: ${response.status}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('API request failed:', error);
    // Handle error appropriately in your application
    throw error;
  }
}
```

### Uploading Large Audio Files

When uploading large audio files, consider implementing chunked uploads or progress tracking:

```javascript
function uploadLargeFile(file, url, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const formData = new FormData();
    
    formData.append('file', file);
    
    xhr.open('POST', url, true);
    
    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable && onProgress) {
        const percentComplete = (event.loaded / event.total) * 100;
        onProgress(percentComplete);
      }
    };
    
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(JSON.parse(xhr.responseText));
      } else {
        reject(new Error(`Upload failed: ${xhr.status}`));
      }
    };
    
    xhr.onerror = () => {
      reject(new Error('Network error during upload'));
    };
    
    xhr.send(formData);
  });
}
```

### Caching Strategies

To improve performance and reduce API calls, implement caching for frequently accessed data:

```javascript
class ApiCache {
  constructor(ttl = 60000) { // Default TTL: 1 minute
    this.cache = new Map();
    this.ttl = ttl;
  }
  
  async get(key, fetchFn) {
    const now = Date.now();
    const cached = this.cache.get(key);
    
    if (cached && now - cached.timestamp < this.ttl) {
      return cached.data;
    }
    
    const data = await fetchFn();
    this.cache.set(key, { data, timestamp: now });
    return data;
  }
  
  invalidate(key) {
    this.cache.delete(key);
  }
  
  clear() {
    this.cache.clear();
  }
}

// Usage example
const apiCache = new ApiCache();

async function getCachedSpeakers() {
  return apiCache.get('speakers', () => 
    fetch('https://speaker-id-server-production.up.railway.app/api/speakers')
      .then(res => res.json())
  );
}
```

## Conclusion

The Speaker ID Server provides a comprehensive API for speaker identification and diarization in audio conversations. By following this integration guide, you can effectively incorporate these capabilities into your own applications.

For any issues or questions, please refer to the GitHub repository at https://github.com/banddude/speaker-id-server or visit the live application at https://speaker-id-server-production.up.railway.app.
