-- insert mock data into our tables
INSERT INTO public.users (display_name, handle, email, cognito_user_id)
VALUES
  ('Yah King', 'yah_king', 'yah_king@test.com', 'MOCK'),
  ('Gentle Warrior', 'gee_warrior', 'gee_warrior@test.com', 'MOCK'),
  ('Andrew Brown', 'andrewbrown', 'andrewbrown@test.com', 'MOCK'),
  ('Andrew Bayko', 'bayko', 'bayko@test.com', 'MOCK'),
  ('Zeus Sucker', 'godofthunder', 'godofthunder@test.com', 'MOCK');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'godofthunder' LIMIT 1),
    'This was imported as seed data!',
    current_timestamp + interval '10 day'
  )