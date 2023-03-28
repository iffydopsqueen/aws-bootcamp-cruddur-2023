-- Adding a UUID Extension 
/* this feature generates long unique identifiers for our users instead of just 
using 1, 2, or 3 as our IDs */

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- the name public is like a namespace for schemas in postgres 
-- you can still create the tables without specifying "public"

-- this deletes the table "users" if it already exists
DROP TABLE IF EXISTS public.users; 

-- create a table called "users"
CREATE TABLE public.users (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  display_name text,
  handle text,
  email text,
  cognito_user_id text,
  created_at TIMESTAMP default current_timestamp NOT NULL
);


-- this deletes the table "activities" if it already exists
DROP TABLE IF EXISTS public.activities;

-- create a table called "activities"
CREATE TABLE public.activities (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_uuid UUID NOT NULL,
  message text NOT NULL,
  replies_count integer DEFAULT 0,
  reposts_count integer DEFAULT 0,
  likes_count integer DEFAULT 0,
  reply_to_activity_uuid integer,
  expires_at TIMESTAMP,
  created_at TIMESTAMP default current_timestamp NOT NULL
);
