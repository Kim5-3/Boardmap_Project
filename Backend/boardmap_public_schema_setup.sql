-- Reviewed equivalent of Alembic revision 0001_initial for a fresh public schema.
-- Run as the database owner in boardmap_db. This does not touch system_core.
-- It grants only the SELECT/INSERT and ID-sequence access needed for register/login.
BEGIN;

DO $$
BEGIN
    IF to_regclass('public.users') IS NOT NULL
       OR to_regclass('public.boarding_houses') IS NOT NULL
       OR to_regclass('public.favorites') IS NOT NULL
       OR to_regclass('public.alembic_version') IS NOT NULL THEN
        RAISE EXCEPTION 'Expected public schema objects are not empty; aborting without changes';
    END IF;
END
$$;

CREATE TABLE public.users (
    id SERIAL NOT NULL PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    username VARCHAR(40) NOT NULL,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(16) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE UNIQUE INDEX public.ix_users_username ON public.users (username);
CREATE UNIQUE INDEX public.ix_users_email ON public.users (email);

CREATE TABLE public.boarding_houses (
    id SERIAL NOT NULL PRIMARY KEY,
    owner_id INTEGER NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    name VARCHAR(160) NOT NULL,
    location VARCHAR(240) NOT NULL,
    description TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    available_rooms INTEGER NOT NULL,
    room_type VARCHAR(40) NOT NULL,
    amenities TEXT NOT NULL,
    rules TEXT NOT NULL,
    curfew_details TEXT NOT NULL,
    safety_features TEXT NOT NULL,
    utility_details TEXT NOT NULL,
    gender_policy VARCHAR(100) NOT NULL,
    deposit_terms TEXT NOT NULL,
    campus_distance_km NUMERIC(8, 2),
    status VARCHAR(20) NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX public.ix_boarding_houses_location ON public.boarding_houses (location);
CREATE INDEX public.ix_boarding_houses_status ON public.boarding_houses (status);
CREATE INDEX public.ix_boarding_houses_owner_id ON public.boarding_houses (owner_id);
CREATE INDEX public.ix_boarding_houses_name ON public.boarding_houses (name);

CREATE TABLE public.favorites (
    id SERIAL NOT NULL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    boarding_house_id INTEGER NOT NULL REFERENCES public.boarding_houses (id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_favorite_user_house UNIQUE (user_id, boarding_house_id)
);
CREATE INDEX public.ix_favorites_user_id ON public.favorites (user_id);
CREATE INDEX public.ix_favorites_boarding_house_id ON public.favorites (boarding_house_id);

CREATE TABLE public.alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);
INSERT INTO public.alembic_version (version_num) VALUES ('0001_initial');

GRANT USAGE ON SCHEMA public TO boardmap_test_reader;
GRANT SELECT, INSERT ON TABLE public.users TO boardmap_test_reader;
GRANT USAGE ON SEQUENCE public.users_id_seq TO boardmap_test_reader;

COMMIT;
