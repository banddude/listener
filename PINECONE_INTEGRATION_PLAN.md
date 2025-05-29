# Pinecone-Speaker Integration Implementation Plan

## Database Changes
- [x] Add `pinecone_speaker_name TEXT NULL` to speakers table
- [x] Add index on `pinecone_speaker_name` field

## Priority 1: Basic Linking ✅
### Backend Changes
- [x] Update `/api/speakers` endpoint to return `pinecone_speaker_name` field
- [x] Add `PUT /api/speakers/{speaker_id}/link-pinecone` endpoint 
- [x] Add `DELETE /api/speakers/{speaker_id}/unlink-pinecone` endpoint

### Frontend Changes  
- [ ] Update SpeakerIDService to handle new field
- [ ] Update Speaker data model to include `pinecone_speaker_name`
- [ ] Show Pinecone connection status in SpeakersListView
- [ ] Add Link/Unlink buttons in speaker cards
- [ ] Test linking functionality

## Priority 2: Auto-Linking 🔄
- [ ] Modify conversation processing to auto-set `pinecone_speaker_name` when Pinecone match found
- [ ] Update database operations to include new field in speaker creation/updates

## Priority 3: Promotion Features 📈
- [ ] Add `POST /api/speakers/{speaker_id}/promote-to-pinecone` endpoint
- [ ] Add validation to ensure Pinecone speaker names are unique per database speaker

## Priority 4: Enhanced Features ✨
- [ ] Add endpoint to get all unlinked speakers
- [ ] Add endpoint to get all linked speakers with their Pinecone embedding counts

## Current Status
**Working on:** Priority 1 Frontend Implementation & Testing
**Backend Status:** ✅ Deployed to Railway (commit 69e27db)
**Next:** Test backend endpoints, then implement iOS frontend 