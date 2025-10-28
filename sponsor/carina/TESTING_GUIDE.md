# Carina Portal Testing Guide

**Goal**: Get the Carina portal running locally and test all features.

**Time Required**: ~30-45 minutes (first time)

---

## Prerequisites

Check you have these installed:

```bash
# Flutter 3.24+
flutter --version

# Dart 3.5+
dart --version

# Chrome (for web development)
google-chrome --version  # or chromium --version
```

If you need to install Flutter:
```bash
# Quick install (if not already installed)
# See: https://docs.flutter.dev/get-started/install/linux
```

---

## Step 1: Create Supabase Project (5 minutes)

### 1.1 Sign Up / Log In
1. Go to https://supabase.com
2. Sign in with GitHub (recommended) or email
3. Click "New Project"

### 1.2 Create Project
- **Organization**: Create new or select existing
- **Name**: `carina-portal-dev` (or similar)
- **Database Password**: Generate strong password (SAVE THIS!)
- **Region**: Choose closest to you (e.g., `us-west-1`)
- **Pricing Plan**: Free tier is fine for testing
- Click "Create new project"

**⏱️ Wait 2-3 minutes** for project to initialize.

### 1.3 Get Credentials
Once project is ready:

1. Click "Settings" (gear icon in sidebar)
2. Click "API" under Project Settings
3. Copy these values (keep browser tab open):
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public** key: Long string starting with `eyJ...`
   - **service_role** key: Long string starting with `eyJ...`

---

## Step 2: Deploy Database Schema (5 minutes)

### 2.1 Open SQL Editor
1. In Supabase dashboard, click "SQL Editor" in left sidebar
2. Click "New Query"

### 2.2 Run Schema Script
1. Open the schema file on your local machine:
   ```bash
   cat /home/mclew/dev24/diary/database/schema.sql
   ```

2. Copy the ENTIRE contents

3. Paste into Supabase SQL Editor

4. Click "Run" (or press Ctrl+Enter)

**Expected**: You should see "Success. No rows returned" (this is normal!)

### 2.3 Verify Tables Created
1. Click "Table Editor" in left sidebar
2. You should see these tables:
   - `sites`
   - `portal_users`
   - `patients`
   - `questionnaires`
   - `record_audit`
   - `record_state`

---

## Step 3: Deploy RLS Policies (3 minutes)

### 3.1 Run RLS Script
1. In SQL Editor, click "New Query"
2. Open RLS policies file:
   ```bash
   cat /home/mclew/dev24/diary/database/rls_policies.sql
   ```

3. Copy entire contents
4. Paste into SQL Editor
5. Click "Run"

**Expected**: "Success. No rows returned"

---

## Step 4: Create Seed Data (5 minutes)

### 4.1 Create Test Site
In SQL Editor, run:

```sql
-- Create a test site
INSERT INTO sites (site_id, site_name, site_number, is_active)
VALUES ('site-001', 'Test Site Alpha', '001', true);
```

### 4.2 Create Admin User
**IMPORTANT**: First, you need to create an auth user in Supabase Auth:

1. In Supabase dashboard, click "Authentication" → "Users"
2. Click "Add user" → "Create new user"
3. Email: `admin@test.com`
4. Password: `TestPass123!` (or your choice)
5. Click "Create user"
6. **Copy the UUID** shown (looks like: `a1b2c3d4-...`)

Now create the portal user record in SQL Editor:

```sql
-- Link portal user to auth user
-- REPLACE 'your-auth-uuid-here' with the UUID you just copied!
INSERT INTO portal_users (id, email, name, role, is_active)
VALUES (
  'your-auth-uuid-here',  -- ← REPLACE THIS!
  'admin@test.com',
  'Test Admin',
  'admin',
  true
);
```

### 4.3 Create Test Investigator
1. In Authentication → Users, create another user:
   - Email: `investigator@test.com`
   - Password: `TestPass123!`
   - Copy UUID

2. In SQL Editor:
```sql
-- Link investigator to auth user
-- REPLACE 'your-investigator-uuid-here' with the UUID!
INSERT INTO portal_users (id, email, name, role, assigned_sites, is_active)
VALUES (
  'your-investigator-uuid-here',  -- ← REPLACE THIS!
  'investigator@test.com',
  'Test Investigator',
  'investigator',
  ARRAY['site-001'],  -- Assigned to site-001
  true
);
```

### 4.4 Create Test Auditor
1. Create auth user:
   - Email: `auditor@test.com`
   - Password: `TestPass123!`
   - Copy UUID

2. In SQL Editor:
```sql
-- Link auditor to auth user
INSERT INTO portal_users (id, email, name, role, is_active)
VALUES (
  'your-auditor-uuid-here',  -- ← REPLACE THIS!
  'auditor@test.com',
  'Test Auditor',
  'auditor',
  true
);
```

---

## Step 5: Configure Portal Credentials (2 minutes)

### 5.1 Create Credentials File
```bash
cd /home/mclew/dev24/diary/sponsor/carina/config
cp supabase.env.example supabase.env
```

### 5.2 Edit Credentials
Open the file:
```bash
nano supabase.env
# or
code supabase.env
```

Fill in your values from Step 1.3:
```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbG...  (your anon key)
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...  (your service role key)
```

Save and exit (Ctrl+X, Y, Enter for nano).

### 5.3 Update Portal Code
Open the Supabase config file:
```bash
nano /home/mclew/dev24/diary/sponsor/carina/lib/portal/lib/config/supabase_config.dart
```

Replace the placeholder values:
```dart
class SupabaseConfig {
  // Replace these with your actual values!
  static const String supabaseUrl = 'https://xxxxx.supabase.co';
  static const String supabaseAnonKey = 'eyJhbG...';

  // Rest stays the same...
}
```

---

## Step 6: Install Flutter Dependencies (2 minutes)

```bash
cd /home/mclew/dev24/diary/sponsor/carina/lib/portal
flutter pub get
```

**Expected**: Should download all packages without errors.

If you see errors about Flutter version:
```bash
flutter upgrade
flutter pub get
```

---

## Step 7: Run the Portal! (2 minutes)

### 7.1 Start Development Server
```bash
cd /home/mclew/dev24/diary/sponsor/carina/lib/portal
flutter run -d chrome
```

**Expected**:
- Chrome browser opens automatically
- Portal loads at `http://localhost:xxxxx`
- You see the login page with "Carina Clinical Trial Portal" title

**If Chrome doesn't open automatically**:
```bash
# List available devices
flutter devices

# Run on specific Chrome
flutter run -d chrome
```

---

## Step 8: Test Features (15 minutes)

### 8.1 Test Admin Login
1. Email: `admin@test.com`
2. Password: `TestPass123!`
3. Click "Sign In"

**Expected**: Redirects to Admin Dashboard with two tabs:
- Users tab (showing your test users)
- Patients tab (empty for now)

### 8.2 Test User Management
1. Click "Create User" button
2. Fill in:
   - Name: `Test User 2`
   - Email: `test2@example.com`
   - Role: `Investigator`
   - Sites: Check `Test Site Alpha`
3. Click "Create"

**Expected**:
- Dialog shows generated linking code (10 characters: `XXXXX-XXXXX`)
- User appears in Users table with "Active" status

### 8.3 Test Admin Patient Overview
1. Click "Patients" tab in left rail

**Expected**:
- Shows "All Patients" header
- Summary cards show: Total=0, Active Today=0, Requires Follow-up=0
- Empty patient table (no patients enrolled yet)

### 8.4 Test Investigator Login
1. Click profile icon → "Sign Out"
2. Login with:
   - Email: `investigator@test.com`
   - Password: `TestPass123!`

**Expected**: Redirects to Investigator Dashboard with:
- "Monitor" tab (patient monitoring)
- "Enroll" tab (patient enrollment)

### 8.5 Test Patient Enrollment
1. Click "Enroll" tab in left rail
2. Fill in form:
   - Patient ID: `001-0000001` (format: SSS-PPPPPPP)
   - Clinical Site: Select "Test Site Alpha (001)"
3. Click "Enroll Patient"

**Expected**:
- Success dialog appears
- Shows linking code (e.g., `AB3D5-FG7H9`)
- Option to copy code
- Patient ID field clears

### 8.6 Test Patient Monitoring
1. Click "Monitor" tab
2. Look at the patient table

**Expected**:
- Shows patient `001-0000001`
- Site: `Test Site Alpha`
- Status badge: **Grey (No Data)** (patient hasn't entered diary data)
- Days Without Data: `Never`
- Last Login: `Never`
- Two questionnaire columns (NOSE HHT, QoL) with "Send" buttons

### 8.7 Test Questionnaire Management
1. Find patient `001-0000001` in the table
2. Click "Send" under "NOSE HHT" column

**Expected**:
- Button changes to "Pending" with "Resend" option
- Status updates to "Sent"

**Note**: Since there's no mobile app connected, questionnaire won't actually be completed. This is expected for scaffold testing.

### 8.8 Test Auditor Login
1. Sign out
2. Login with:
   - Email: `auditor@test.com`
   - Password: `TestPass123!`

**Expected**:
- Redirects to Auditor Dashboard
- Yellow banner: "AUDIT MODE - Read-Only Access"
- Summary cards show: Total Users=3, Total Patients=1, Active Patients=0
- See all users and patients in tables
- "Export Database" button present (click shows stub message)
- No "Create", "Edit", "Delete" buttons visible

---

## Step 9: Test Token Revocation (Admin)

1. Sign out and login as Admin
2. Go to Users tab
3. Find `Test User 2` in the table
4. Click the "Revoke Access" icon (🚫)
5. Confirm revocation

**Expected**:
- User status changes from "Active" to "Revoked"
- Status badge turns red

---

## Step 10: Test Browser Compatibility (Optional)

### Test in Different Browsers
```bash
# Firefox
flutter run -d web-server --web-port=8080
# Then open http://localhost:8080 in Firefox

# Edge (if available)
# Same as above, open in Edge
```

**Expected**: Portal should work in all modern browsers.

---

## Common Issues & Solutions

### Issue: "No devices found"
**Solution**:
```bash
# Make sure Chrome is installed
google-chrome --version

# Enable web support
flutter config --enable-web
flutter devices
```

### Issue: "Supabase connection error"
**Solution**:
- Check `supabase_config.dart` has correct URL and key
- Check browser console (F12) for CORS errors
- Verify Supabase project is active (not paused)

### Issue: "Login fails"
**Solution**:
- Verify user exists in Supabase Authentication → Users
- Check email/password is correct
- Verify portal_users record exists with matching UUID
- Check browser console for errors

### Issue: "RLS policy error" / "Permission denied"
**Solution**:
- Re-run RLS policies script from Step 3
- Check user role is set correctly in portal_users table
- Verify user's assigned_sites array matches site_id

### Issue: "Build errors"
**Solution**:
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Issue: "Can't see patients as Investigator"
**Solution**:
- Check investigator's `assigned_sites` array includes the site
- Verify patient's `site_id` matches an assigned site
- Check RLS policies are deployed

---

## Expected Test Results Summary

After completing all steps, you should have:

✅ **Admin Dashboard**:
- Created and revoked users
- Viewed patient overview
- Generated linking codes

✅ **Investigator Dashboard**:
- Enrolled patient with IRT ID
- Viewed patient in monitoring table
- Sent questionnaire (NOSE HHT)
- Saw status indicators

✅ **Auditor Dashboard**:
- Viewed all users and patients (read-only)
- Saw "AUDIT MODE" indicator
- Database export button visible

✅ **Authentication**:
- Logged in as all three roles
- Role-based redirects worked
- Sign out worked

✅ **Data Isolation**:
- Investigator only saw patients from assigned site
- Auditor saw all data
- Admin saw all users and patients

---

## Next Steps After Testing

### If Everything Works ✅
1. Test with more realistic data (multiple sites, patients, investigators)
2. Replace placeholder branding assets
3. Deploy to staging environment (Netlify/Vercel)
4. Test on mobile browsers (responsive design)
5. Conduct UAT with sponsor stakeholders

### If Issues Found 🐛
1. Document issues in GitHub issues or Linear tickets
2. Check browser console for error details
3. Review Supabase logs (Dashboard → Logs)
4. Test individual features in isolation
5. Report blockers for resolution

---

## Clean Up (Optional)

To start fresh:

### Delete Test Data
In Supabase SQL Editor:
```sql
-- Delete test data (keeps schema)
DELETE FROM questionnaires;
DELETE FROM patients;
DELETE FROM portal_users;
DELETE FROM sites;
```

### Delete Supabase Project
1. Settings → General
2. Scroll to "Danger Zone"
3. "Pause project" or "Delete project"

---

## Support

**Issues with Supabase**: https://supabase.com/docs
**Flutter Web Issues**: https://docs.flutter.dev/platform-integration/web
**Portal Documentation**: `sponsor/carina/lib/portal/README.md`

---

**Testing Guide Version**: 1.0
**Last Updated**: 2025-10-27
**Estimated Time**: 30-45 minutes (first time), 10-15 minutes (subsequent)
