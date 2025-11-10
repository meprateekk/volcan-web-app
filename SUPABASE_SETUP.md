# Supabase Setup Guide for VisionVolcan Site App

## Overview
Your `site_list_screen.dart` has been successfully integrated with Supabase. The app now uses Supabase as the backend database for all site operations.

## Changes Made

### 1. **site_list_screen.dart**
- ✅ Fixed syntax error (removed 'jjj' on line 73)
- ✅ Added `_sites` list and `_isLoading` state variables
- ✅ Added `_refreshSites()` method to fetch sites from Supabase
- ✅ Updated UI to show loading spinner while fetching data
- ✅ Fixed `FutureBuilder` to `ListView.builder` for proper rendering
- ✅ Made all CRUD operations async with proper error handling
- ✅ Added success/error notifications for all operations

### 2. **site_service.dart**
- ✅ Removed local `_sites` array (data now comes from Supabase)
- ✅ Updated `getSites()` to properly return data from Supabase
- ✅ Made `addSite()` async - now inserts into Supabase
- ✅ Made `deleteSite()` async - now deletes from Supabase
- ✅ Made `markSiteAsCompleted()` async - now updates in Supabase
- ✅ Made `updateSiteField()` async - now updates in Supabase

## Required: Supabase Database Table Setup

You need to create a `sites` table in your Supabase database with the following structure:

### SQL to Create Table

```sql
CREATE TABLE sites (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  location TEXT NOT NULL,
  plotSize TEXT,
  floors TEXT,
  startDate TEXT,
  dueDate TEXT,
  status TEXT DEFAULT 'ongoing',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

-- Create policy to allow authenticated users to do everything
CREATE POLICY "Allow authenticated users full access"
  ON sites
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);
```

### Steps to Create the Table:

1. **Go to your Supabase Dashboard**
   - Navigate to: https://nxxrobftgkkqybbvilub.supabase.co

2. **Open SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New query"

3. **Run the SQL**
   - Copy and paste the SQL above
   - Click "Run" or press `Ctrl+Enter`

4. **Verify Table Creation**
   - Click on "Table Editor" in the left sidebar
   - You should see the `sites` table

### Optional: Add Sample Data

```sql
INSERT INTO sites (name, location, plotSize, floors, startDate, dueDate, status) VALUES
  ('Greenwood Project', 'Gwalior, MP', '50 x 80 ft', '3', '01 Jan 2025', '15 Dec 2026', 'ongoing'),
  ('Downtown Plaza', 'Morena, MP', '100 x 120 ft', '5', '05 Jan 2025', '31 Jan 2027', 'ongoing'),
  ('City Center Mall', 'Bhopal, MP', '200 x 300 ft', '10', '10 Dec 2024', '01 Mar 2028', 'completed');
```

## How It Works Now

### Authentication Flow
1. User logs in via `login_screen.dart` using email/password
2. Supabase validates credentials
3. On success, navigates to `site_list_screen.dart`

### Site Operations
- **Load Sites**: Automatically fetches from Supabase on screen load
- **Add Site**: Creates new record in Supabase database
- **Delete Site**: Removes record from Supabase database
- **Mark Complete**: Updates site status to 'completed' in Supabase
- **All operations show success/error messages**

## Testing Checklist

- [ ] Create the `sites` table in Supabase
- [ ] Run the app and login with valid credentials
- [ ] Verify sites load from database
- [ ] Test adding a new site
- [ ] Test marking a site as completed
- [ ] Test deleting a site
- [ ] Verify all operations update the database

## Troubleshooting

### "Table 'sites' does not exist"
- You haven't created the table yet
- Run the SQL from the setup section above

### "Permission denied for table sites"
- RLS (Row Level Security) is blocking access
- Make sure you created the policy (last part of the SQL)
- Check that you're logged in (authenticated)

### "Error loading sites"
- Check your internet connection
- Verify Supabase URL and anon key in `main.dart`
- Check Supabase dashboard for any service issues

## Next Steps

1. Create the `sites` table in Supabase (if not done)
2. Test all CRUD operations
3. Consider adding:
   - User-specific sites (filter by user ID)
   - Real-time updates using Supabase subscriptions
   - Image uploads for sites
   - More detailed site information fields

## Important Notes

- The app uses the Supabase client initialized in `main.dart`
- All database operations require authentication
- Make sure to handle the `id` field returned by Supabase (it's auto-generated)
- Error messages are displayed as SnackBars to the user
