--
-- PostgreSQL database dump
--

\restrict x5JegMtRJjQPM7hcNg6FZX6sxo0BJbN9WT3d3wePassEphMH9ymCK9ZzBCxNCKx

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg12+1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: atom_profile; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.atom_profile AS ENUM (
    'lightweight',
    'standard',
    'full'
);


--
-- Name: atom_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.atom_state AS ENUM (
    'active',
    'fading',
    'dormant',
    'tombstone'
);


--
-- Name: atom_stream; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.atom_stream AS ENUM (
    'semantic',
    'episodic',
    'procedural',
    'working'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: atom_co_retrievals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.atom_co_retrievals (
    atom_a bigint NOT NULL,
    atom_b bigint NOT NULL,
    count integer DEFAULT 1 NOT NULL,
    last_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT atom_co_retrievals_check CHECK ((atom_a < atom_b))
);


--
-- Name: atom_outcomes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.atom_outcomes (
    id bigint NOT NULL,
    atom_id bigint NOT NULL,
    session_id text NOT NULL,
    signal real NOT NULL,
    reason text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: atom_outcomes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.atom_outcomes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: atom_outcomes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.atom_outcomes_id_seq OWNED BY public.atom_outcomes.id;


--
-- Name: atoms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.atoms (
    id bigint NOT NULL,
    company_id bigint,
    filer_cik character varying(10),
    chunk_id bigint,
    document_id bigint,
    profile public.atom_profile DEFAULT 'standard'::public.atom_profile NOT NULL,
    stream public.atom_stream DEFAULT 'semantic'::public.atom_stream NOT NULL,
    state public.atom_state DEFAULT 'active'::public.atom_state NOT NULL,
    content text NOT NULL,
    content_hash text NOT NULL,
    token_count integer NOT NULL,
    source_quote text,
    access_count integer DEFAULT 0 NOT NULL,
    last_accessed_at timestamp with time zone,
    stability real DEFAULT 1.0 NOT NULL,
    retrievability real DEFAULT 1.0 NOT NULL,
    arousal real DEFAULT 0.0 NOT NULL,
    valence real DEFAULT 0.0 NOT NULL,
    encoding_confidence real DEFAULT 0.7 NOT NULL,
    embedding public.vector(384),
    topics text[] DEFAULT '{}'::text[] NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_pinned boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE atoms; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.atoms IS 'MSAM-style memory atoms. Compressed claims extracted from chunks. Scored by ACT-R activation. Decay over time. Never deleted.';


--
-- Name: atoms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.atoms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: atoms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.atoms_id_seq OWNED BY public.atoms.id;


--
-- Name: chunks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chunks (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    ordinal integer NOT NULL,
    text text NOT NULL,
    token_count integer NOT NULL,
    start_char integer NOT NULL,
    end_char integer NOT NULL,
    speaker text,
    section text,
    dense_vec public.vector(96),
    colbert_blob bytea NOT NULL,
    colbert_dim integer DEFAULT 96 NOT NULL,
    colbert_tokens integer NOT NULL,
    text_tsv tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, text)) STORED,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE chunks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.chunks IS 'ColBERT-indexed text spans. dense_vec for first-pass HNSW; colbert_blob for late-interaction re-rank in the Python sidecar.';


--
-- Name: chunks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chunks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chunks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chunks_id_seq OWNED BY public.chunks.id;


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id bigint NOT NULL,
    cusip character varying(9) NOT NULL,
    ticker character varying(10),
    cik character varying(10),
    name text NOT NULL,
    sector text,
    industry text,
    exchange character varying(20),
    ir_url text,
    rss_url text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE companies; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.companies IS 'Canonical company record. One row per CUSIP. Populated from cusip_symbol_mappings during initial seed.';


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id text NOT NULL,
    title text,
    shared boolean DEFAULT false NOT NULL,
    share_slug text,
    context jsonb DEFAULT '[]'::jsonb NOT NULL,
    messages jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id bigint NOT NULL,
    company_id bigint,
    doc_type text NOT NULL,
    source text NOT NULL,
    source_ref text,
    title text,
    authors text[] DEFAULT '{}'::text[] NOT NULL,
    published_at timestamp with time zone NOT NULL,
    fiscal_period text,
    raw_text text,
    raw_url text,
    language character varying(8) DEFAULT 'en'::character varying NOT NULL,
    word_count integer,
    hash text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    ingested_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone
);


--
-- Name: TABLE documents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.documents IS 'Raw source documents. One per news article, earnings call, SEC filing. Deduped by (source, source_ref) and by hash.';


--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: triples; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.triples (
    id bigint NOT NULL,
    subject text NOT NULL,
    predicate text NOT NULL,
    object text NOT NULL,
    confidence real DEFAULT 0.7 NOT NULL,
    valid_from timestamp with time zone DEFAULT now() NOT NULL,
    valid_until timestamp with time zone,
    source_atom_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE triples; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.triples IS 'Knowledge graph. Carries temporal metadata so historical state can be reconstructed. Updating a fact auto-closes the old triple.';


--
-- Name: triples_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.triples_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: triples_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.triples_id_seq OWNED BY public.triples.id;


--
-- Name: atom_outcomes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atom_outcomes ALTER COLUMN id SET DEFAULT nextval('public.atom_outcomes_id_seq'::regclass);


--
-- Name: atoms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atoms ALTER COLUMN id SET DEFAULT nextval('public.atoms_id_seq'::regclass);


--
-- Name: chunks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chunks ALTER COLUMN id SET DEFAULT nextval('public.chunks_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: triples id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triples ALTER COLUMN id SET DEFAULT nextval('public.triples_id_seq'::regclass);


--
-- Name: atom_co_retrievals atom_co_retrievals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atom_co_retrievals
    ADD CONSTRAINT atom_co_retrievals_pkey PRIMARY KEY (atom_a, atom_b);


--
-- Name: atom_outcomes atom_outcomes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atom_outcomes
    ADD CONSTRAINT atom_outcomes_pkey PRIMARY KEY (id);


--
-- Name: atoms atoms_content_hash_company_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atoms
    ADD CONSTRAINT atoms_content_hash_company_id_key UNIQUE (content_hash, company_id);


--
-- Name: atoms atoms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atoms
    ADD CONSTRAINT atoms_pkey PRIMARY KEY (id);


--
-- Name: chunks chunks_document_id_ordinal_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chunks
    ADD CONSTRAINT chunks_document_id_ordinal_key UNIQUE (document_id, ordinal);


--
-- Name: chunks chunks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chunks
    ADD CONSTRAINT chunks_pkey PRIMARY KEY (id);


--
-- Name: companies companies_cusip_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_cusip_key UNIQUE (cusip);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_share_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_share_slug_key UNIQUE (share_slug);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: documents documents_source_source_ref_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_source_source_ref_key UNIQUE (source, source_ref);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: triples triples_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triples
    ADD CONSTRAINT triples_pkey PRIMARY KEY (id);


--
-- Name: triples triples_subject_predicate_object_valid_from_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triples
    ADD CONSTRAINT triples_subject_predicate_object_valid_from_key UNIQUE (subject, predicate, object, valid_from);


--
-- Name: atom_co_retrievals_a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atom_co_retrievals_a ON public.atom_co_retrievals USING btree (atom_a, count DESC);


--
-- Name: atom_co_retrievals_b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atom_co_retrievals_b ON public.atom_co_retrievals USING btree (atom_b, count DESC);


--
-- Name: atom_outcomes_atom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atom_outcomes_atom ON public.atom_outcomes USING btree (atom_id, created_at DESC);


--
-- Name: atom_outcomes_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atom_outcomes_session ON public.atom_outcomes USING btree (session_id, created_at DESC);


--
-- Name: atoms_active_recent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atoms_active_recent ON public.atoms USING btree (last_accessed_at DESC) WHERE (state = 'active'::public.atom_state);


--
-- Name: atoms_company_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atoms_company_state ON public.atoms USING btree (company_id, state, retrievability DESC);


--
-- Name: atoms_embedding_hnsw; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atoms_embedding_hnsw ON public.atoms USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: atoms_filer_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atoms_filer_state ON public.atoms USING btree (filer_cik, state) WHERE (filer_cik IS NOT NULL);


--
-- Name: atoms_last_accessed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atoms_last_accessed ON public.atoms USING btree (last_accessed_at);


--
-- Name: atoms_topics_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atoms_topics_gin ON public.atoms USING gin (topics);


--
-- Name: chunks_dense_vec_hnsw; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chunks_dense_vec_hnsw ON public.chunks USING hnsw (dense_vec public.vector_cosine_ops);


--
-- Name: chunks_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chunks_document ON public.chunks USING btree (document_id, ordinal);


--
-- Name: chunks_text_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chunks_text_tsv ON public.chunks USING gin (text_tsv);


--
-- Name: companies_cik_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_cik_idx ON public.companies USING btree (cik);


--
-- Name: companies_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_name_trgm ON public.companies USING gin (name public.gin_trgm_ops);


--
-- Name: companies_ticker_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_ticker_idx ON public.companies USING btree (ticker);


--
-- Name: conversations_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversations_session ON public.conversations USING btree (session_id, updated_at DESC);


--
-- Name: conversations_share; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversations_share ON public.conversations USING btree (share_slug) WHERE (share_slug IS NOT NULL);


--
-- Name: documents_company_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_company_published ON public.documents USING btree (company_id, published_at DESC);


--
-- Name: documents_doc_type_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_doc_type_published ON public.documents USING btree (doc_type, published_at DESC);


--
-- Name: documents_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_hash ON public.documents USING btree (hash);


--
-- Name: documents_unprocessed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_unprocessed ON public.documents USING btree (ingested_at) WHERE (processed_at IS NULL);


--
-- Name: triples_currently_valid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX triples_currently_valid ON public.triples USING btree (subject, predicate) WHERE (valid_until IS NULL);


--
-- Name: triples_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX triples_subject ON public.triples USING btree (subject);


--
-- Name: triples_subject_predicate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX triples_subject_predicate ON public.triples USING btree (subject, predicate);


--
-- Name: triples_valid_window; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX triples_valid_window ON public.triples USING btree (valid_from, valid_until);


--
-- Name: atom_co_retrievals atom_co_retrievals_atom_a_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atom_co_retrievals
    ADD CONSTRAINT atom_co_retrievals_atom_a_fkey FOREIGN KEY (atom_a) REFERENCES public.atoms(id) ON DELETE CASCADE;


--
-- Name: atom_co_retrievals atom_co_retrievals_atom_b_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atom_co_retrievals
    ADD CONSTRAINT atom_co_retrievals_atom_b_fkey FOREIGN KEY (atom_b) REFERENCES public.atoms(id) ON DELETE CASCADE;


--
-- Name: atom_outcomes atom_outcomes_atom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atom_outcomes
    ADD CONSTRAINT atom_outcomes_atom_id_fkey FOREIGN KEY (atom_id) REFERENCES public.atoms(id) ON DELETE CASCADE;


--
-- Name: atoms atoms_chunk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atoms
    ADD CONSTRAINT atoms_chunk_id_fkey FOREIGN KEY (chunk_id) REFERENCES public.chunks(id) ON DELETE SET NULL;


--
-- Name: atoms atoms_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atoms
    ADD CONSTRAINT atoms_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE SET NULL;


--
-- Name: atoms atoms_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atoms
    ADD CONSTRAINT atoms_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE SET NULL;


--
-- Name: chunks chunks_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chunks
    ADD CONSTRAINT chunks_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE;


--
-- Name: documents documents_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: triples triples_source_atom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triples
    ADD CONSTRAINT triples_source_atom_id_fkey FOREIGN KEY (source_atom_id) REFERENCES public.atoms(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict x5JegMtRJjQPM7hcNg6FZX6sxo0BJbN9WT3d3wePassEphMH9ymCK9ZzBCxNCKx

