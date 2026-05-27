\restrict zHf02TRv88GfhHEAnODwjO40PpW3DTtC1Q6nyOGa0ESSonWer3EvwYgF3larsT1

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
-- Name: aggregate_holdings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aggregate_holdings (
    id bigint NOT NULL,
    thirteen_f_id bigint NOT NULL,
    cusip text NOT NULL,
    issuer_name text,
    class_title text,
    value numeric,
    shares_or_principal_amount numeric,
    shares_or_principal_amount_type text,
    option_type text,
    voting_authority_sole bigint,
    voting_authority_shared bigint,
    voting_authority_none bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: aggregate_holdings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aggregate_holdings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aggregate_holdings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aggregate_holdings_id_seq OWNED BY public.aggregate_holdings.id;


--
-- Name: ai_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_conversations (
    id bigint NOT NULL,
    session_id character varying NOT NULL,
    title character varying,
    messages jsonb DEFAULT '[]'::jsonb NOT NULL,
    context jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_conversations_id_seq OWNED BY public.ai_conversations.id;


--
-- Name: ai_insights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_insights (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    filer_cik character varying,
    filer_name character varying,
    cusip character varying,
    headline text NOT NULL,
    body text NOT NULL,
    tags character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    confidence double precision DEFAULT 0.5 NOT NULL,
    model character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_insights_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_insights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_insights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_insights_id_seq OWNED BY public.ai_insights.id;


--
-- Name: ai_provider_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_provider_configs (
    id bigint NOT NULL,
    session_id character varying NOT NULL,
    provider character varying NOT NULL,
    api_key_ciphertext text,
    default_model character varying,
    endpoint character varying,
    last_used_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_provider_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_provider_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_provider_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_provider_configs_id_seq OWNED BY public.ai_provider_configs.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


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
-- Name: cusip_symbol_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cusip_symbol_mappings (
    id bigint NOT NULL,
    cusip text NOT NULL,
    symbol text,
    name text,
    exchange text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    source character varying DEFAULT 'manual'::character varying NOT NULL,
    confidence double precision DEFAULT 1.0 NOT NULL,
    cik character varying,
    verified_at timestamp without time zone
);


--
-- Name: company_cusip_lookups; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.company_cusip_lookups AS
 WITH holding_counts AS (
         SELECT aggregate_holdings.cusip,
            aggregate_holdings.issuer_name,
            aggregate_holdings.class_title,
            aggregate_holdings.shares_or_principal_amount_type,
            count(*) AS holdings_count
           FROM public.aggregate_holdings
          GROUP BY aggregate_holdings.cusip, aggregate_holdings.issuer_name, aggregate_holdings.class_title, aggregate_holdings.shares_or_principal_amount_type
        ), most_common AS (
         SELECT DISTINCT ON (holding_counts.cusip) holding_counts.cusip,
            holding_counts.issuer_name,
            holding_counts.class_title,
            holding_counts.shares_or_principal_amount_type,
            holding_counts.holdings_count
           FROM holding_counts
          ORDER BY holding_counts.cusip, holding_counts.holdings_count DESC, holding_counts.issuer_name, holding_counts.class_title
        )
 SELECT mc.cusip,
    mc.issuer_name,
    mc.class_title,
    mc.shares_or_principal_amount_type,
    mc.holdings_count,
    upper(map.symbol) AS symbol
   FROM (most_common mc
     LEFT JOIN public.cusip_symbol_mappings map ON ((mc.cusip = map.cusip)))
  WITH NO DATA;


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
-- Name: thirteen_fs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thirteen_fs (
    id bigint NOT NULL,
    external_id text NOT NULL,
    cik text NOT NULL,
    name text NOT NULL,
    form_type text NOT NULL,
    directory_url text NOT NULL,
    date_filed date NOT NULL,
    report_date date,
    street1 text,
    street2 text,
    city text,
    state_or_country text,
    zip_code text,
    other_included_managers_count integer,
    holdings_count_reported integer,
    holdings_count_calculated integer,
    holdings_value_reported numeric,
    holdings_value_calculated numeric,
    confidential_omitted boolean,
    filing_year integer NOT NULL,
    filing_quarter integer NOT NULL,
    report_year integer,
    report_quarter integer,
    other_managers jsonb DEFAULT '[]'::jsonb NOT NULL,
    primary_doc_url text,
    info_table_url text,
    primary_doc_xml text,
    info_table_xml text,
    xml_data_fetched_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    report_type text,
    amendment_type text,
    amendment_number integer,
    file_number text,
    restated_by_id bigint,
    aggregate_holdings_count integer
);


--
-- Name: cusip_quarterly_filings_counts; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.cusip_quarterly_filings_counts AS
 SELECT h.cusip,
    f.report_year,
    f.report_quarter,
    count(*) AS filings_count
   FROM (public.thirteen_fs f
     JOIN public.aggregate_holdings h ON ((h.thirteen_f_id = f.id)))
  GROUP BY h.cusip, f.report_year, f.report_quarter
  ORDER BY h.cusip, f.report_year, f.report_quarter
  WITH NO DATA;


--
-- Name: cusip_symbol_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cusip_symbol_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cusip_symbol_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cusip_symbol_mappings_id_seq OWNED BY public.cusip_symbol_mappings.id;


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delayed_jobs (
    id bigint NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    handler text NOT NULL,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by character varying,
    queue character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.delayed_jobs_id_seq OWNED BY public.delayed_jobs.id;


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
-- Name: holdings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.holdings (
    id bigint NOT NULL,
    thirteen_f_id bigint NOT NULL,
    cusip text NOT NULL,
    issuer_name text,
    class_title text,
    value numeric,
    shares_or_principal_amount numeric,
    shares_or_principal_amount_type text,
    option_type text,
    investment_discretion text,
    other_manager text,
    voting_authority_sole bigint,
    voting_authority_shared bigint,
    voting_authority_none bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: holdings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.holdings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: holdings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.holdings_id_seq OWNED BY public.holdings.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: thirteen_f_filers; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.thirteen_f_filers AS
 WITH most_recent AS (
         SELECT DISTINCT ON (thirteen_fs.cik) thirteen_fs.cik,
            thirteen_fs.name,
            thirteen_fs.city,
            thirteen_fs.state_or_country,
            thirteen_fs.date_filed AS most_recent_date_filed
           FROM public.thirteen_fs
          ORDER BY thirteen_fs.cik, thirteen_fs.date_filed DESC, thirteen_fs.id
        ), counts AS (
         SELECT thirteen_fs.cik,
            count(*) AS filings_count
           FROM public.thirteen_fs
          GROUP BY thirteen_fs.cik
        )
 SELECT most_recent.cik,
    most_recent.name,
    most_recent.city,
    most_recent.state_or_country,
    most_recent.most_recent_date_filed,
    counts.filings_count
   FROM (most_recent
     JOIN counts ON ((most_recent.cik = counts.cik)))
  WITH NO DATA;


--
-- Name: thirteen_fs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.thirteen_fs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: thirteen_fs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.thirteen_fs_id_seq OWNED BY public.thirteen_fs.id;


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
-- Name: watchlists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watchlists (
    id bigint NOT NULL,
    session_id character varying NOT NULL,
    name character varying NOT NULL,
    filer_ciks character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    cusips character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    notifications boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: watchlists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.watchlists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: watchlists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.watchlists_id_seq OWNED BY public.watchlists.id;


--
-- Name: aggregate_holdings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aggregate_holdings ALTER COLUMN id SET DEFAULT nextval('public.aggregate_holdings_id_seq'::regclass);


--
-- Name: ai_conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations ALTER COLUMN id SET DEFAULT nextval('public.ai_conversations_id_seq'::regclass);


--
-- Name: ai_insights id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_insights ALTER COLUMN id SET DEFAULT nextval('public.ai_insights_id_seq'::regclass);


--
-- Name: ai_provider_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_provider_configs ALTER COLUMN id SET DEFAULT nextval('public.ai_provider_configs_id_seq'::regclass);


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
-- Name: cusip_symbol_mappings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cusip_symbol_mappings ALTER COLUMN id SET DEFAULT nextval('public.cusip_symbol_mappings_id_seq'::regclass);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs ALTER COLUMN id SET DEFAULT nextval('public.delayed_jobs_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: holdings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holdings ALTER COLUMN id SET DEFAULT nextval('public.holdings_id_seq'::regclass);


--
-- Name: thirteen_fs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thirteen_fs ALTER COLUMN id SET DEFAULT nextval('public.thirteen_fs_id_seq'::regclass);


--
-- Name: triples id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triples ALTER COLUMN id SET DEFAULT nextval('public.triples_id_seq'::regclass);


--
-- Name: watchlists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlists ALTER COLUMN id SET DEFAULT nextval('public.watchlists_id_seq'::regclass);


--
-- Name: aggregate_holdings aggregate_holdings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aggregate_holdings
    ADD CONSTRAINT aggregate_holdings_pkey PRIMARY KEY (id);


--
-- Name: ai_conversations ai_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations
    ADD CONSTRAINT ai_conversations_pkey PRIMARY KEY (id);


--
-- Name: ai_insights ai_insights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_insights
    ADD CONSTRAINT ai_insights_pkey PRIMARY KEY (id);


--
-- Name: ai_provider_configs ai_provider_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_provider_configs
    ADD CONSTRAINT ai_provider_configs_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


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
-- Name: cusip_symbol_mappings cusip_symbol_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cusip_symbol_mappings
    ADD CONSTRAINT cusip_symbol_mappings_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


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
-- Name: holdings holdings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holdings
    ADD CONSTRAINT holdings_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: thirteen_fs thirteen_fs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thirteen_fs
    ADD CONSTRAINT thirteen_fs_pkey PRIMARY KEY (id);


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
-- Name: watchlists watchlists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlists
    ADD CONSTRAINT watchlists_pkey PRIMARY KEY (id);


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
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delayed_jobs_priority ON public.delayed_jobs USING btree (priority, run_at);


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
-- Name: index_aggregate_holdings_on_cusip_and_thirteen_f_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aggregate_holdings_on_cusip_and_thirteen_f_id ON public.aggregate_holdings USING btree (cusip, thirteen_f_id);


--
-- Name: index_aggregate_holdings_on_thirteen_f_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aggregate_holdings_on_thirteen_f_id ON public.aggregate_holdings USING btree (thirteen_f_id);


--
-- Name: index_ai_conversations_on_session_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_conversations_on_session_id_and_updated_at ON public.ai_conversations USING btree (session_id, updated_at);


--
-- Name: index_ai_insights_on_cusip_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_insights_on_cusip_and_created_at ON public.ai_insights USING btree (cusip, created_at);


--
-- Name: index_ai_insights_on_filer_cik_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_insights_on_filer_cik_and_created_at ON public.ai_insights USING btree (filer_cik, created_at);


--
-- Name: index_ai_insights_on_kind_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_insights_on_kind_and_created_at ON public.ai_insights USING btree (kind, created_at);


--
-- Name: index_ai_provider_configs_on_session_id_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_provider_configs_on_session_id_and_provider ON public.ai_provider_configs USING btree (session_id, provider);


--
-- Name: index_company_cusip_lookups_on_count_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_cusip_lookups_on_count_and_name ON public.company_cusip_lookups USING btree (holdings_count, lower(issuer_name));


--
-- Name: index_company_cusip_lookups_on_cusip; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_company_cusip_lookups_on_cusip ON public.company_cusip_lookups USING btree (cusip);


--
-- Name: index_company_cusip_lookups_on_issuer_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_cusip_lookups_on_issuer_name ON public.company_cusip_lookups USING gin (issuer_name public.gin_trgm_ops);


--
-- Name: index_company_cusip_lookups_on_symbol; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_cusip_lookups_on_symbol ON public.company_cusip_lookups USING btree (symbol);


--
-- Name: index_company_cusip_lookups_on_symbol_trigram; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_cusip_lookups_on_symbol_trigram ON public.company_cusip_lookups USING gin (symbol public.gin_trgm_ops);


--
-- Name: index_cusip_quarterly_filings_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cusip_quarterly_filings_unique ON public.cusip_quarterly_filings_counts USING btree (cusip, report_year, report_quarter);


--
-- Name: index_cusip_symbol_mappings_on_cik; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cusip_symbol_mappings_on_cik ON public.cusip_symbol_mappings USING btree (cik);


--
-- Name: index_cusip_symbol_mappings_on_cusip; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cusip_symbol_mappings_on_cusip ON public.cusip_symbol_mappings USING btree (cusip);


--
-- Name: index_cusip_symbol_mappings_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cusip_symbol_mappings_on_source ON public.cusip_symbol_mappings USING btree (source);


--
-- Name: index_cusip_symbol_mappings_on_verified_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cusip_symbol_mappings_on_verified_at ON public.cusip_symbol_mappings USING btree (verified_at);


--
-- Name: index_holdings_on_cusip_and_thirteen_f_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_holdings_on_cusip_and_thirteen_f_id ON public.holdings USING btree (cusip, thirteen_f_id);


--
-- Name: index_holdings_on_thirteen_f_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_holdings_on_thirteen_f_id ON public.holdings USING btree (thirteen_f_id);


--
-- Name: index_thirteen_f_filers_on_cik; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thirteen_f_filers_on_cik ON public.thirteen_f_filers USING btree (cik);


--
-- Name: index_thirteen_f_filers_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_f_filers_on_lower_name ON public.thirteen_f_filers USING btree (lower(name));


--
-- Name: index_thirteen_f_filers_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_f_filers_on_name ON public.thirteen_f_filers USING gin (name public.gin_trgm_ops);


--
-- Name: index_thirteen_fs_on_amendment_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_fs_on_amendment_type ON public.thirteen_fs USING btree (amendment_type);


--
-- Name: index_thirteen_fs_on_cik_and_report_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_fs_on_cik_and_report_date ON public.thirteen_fs USING btree (cik, report_date);


--
-- Name: index_thirteen_fs_on_date_filed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_fs_on_date_filed ON public.thirteen_fs USING btree (date_filed);


--
-- Name: index_thirteen_fs_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thirteen_fs_on_external_id ON public.thirteen_fs USING btree (external_id);


--
-- Name: index_thirteen_fs_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_fs_on_name ON public.thirteen_fs USING gin (name public.gin_trgm_ops);


--
-- Name: index_thirteen_fs_on_report_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_fs_on_report_date ON public.thirteen_fs USING btree (report_date);


--
-- Name: index_thirteen_fs_on_restated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_fs_on_restated_by_id ON public.thirteen_fs USING btree (restated_by_id);


--
-- Name: index_thirteen_fs_on_year_quarter_restated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thirteen_fs_on_year_quarter_restated ON public.thirteen_fs USING btree (report_year, report_quarter, restated_by_id);


--
-- Name: index_watchlists_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watchlists_on_session_id ON public.watchlists USING btree (session_id);


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

\unrestrict zHf02TRv88GfhHEAnODwjO40PpW3DTtC1Q6nyOGa0ESSonWer3EvwYgF3larsT1

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20210206203922'),
('20210206213907'),
('20210207131946'),
('20210207192816'),
('20210215143732'),
('20210228002933'),
('20210313203021'),
('20210327145224'),
('20210327205234'),
('20260520000001'),
('20260520000002'),
('20260520000003'),
('20260527000001'),
('20260527000002'),
('20260527000003'),
('20260527000004'),
('20260527000005'),
('20260527000006'),
('20260527000007'),
('20260527000008'),
('20260527000009');


