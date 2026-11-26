# Backend script for the public report page

`anonymous-submission.sql`: run once in Supabase dashboard > SQL Editor. It adds one controlled door
(`submit_web_report`) and a photo-upload rule so the public page `docs/index.html` can accept reports
without login. Safe to run twice. It only adds things.
