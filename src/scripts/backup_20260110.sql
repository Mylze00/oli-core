--
-- PostgreSQL database dump
--

\restrict hhWjGIUSxVNbiE07cHuejHVIa2Py4iuA886o9vKgPqHxTNZfkcYqLN00b4jcvVT

-- Dumped from database version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)

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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: conversations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.conversations (
    id integer NOT NULL,
    user1_id uuid NOT NULL,
    user2_id uuid NOT NULL,
    product_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.conversations OWNER TO postgres;

--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conversations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.conversations_id_seq OWNER TO postgres;

--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: delivery_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.delivery_orders (
    id integer NOT NULL,
    order_id integer,
    deliverer_id uuid,
    status character varying(20) DEFAULT 'pending'::character varying,
    pickup_address text NOT NULL,
    delivery_address text NOT NULL,
    pickup_lat numeric(10,8),
    pickup_lng numeric(11,8),
    delivery_lat numeric(10,8),
    delivery_lng numeric(11,8),
    current_lat numeric(10,8),
    current_lng numeric(11,8),
    estimated_time character varying(50),
    actual_pickup_time timestamp without time zone,
    actual_delivery_time timestamp without time zone,
    delivery_fee numeric(10,2) DEFAULT 0,
    deliverer_earnings numeric(10,2) DEFAULT 0,
    deliverer_rating integer,
    customer_notes text,
    deliverer_notes text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT delivery_orders_deliverer_rating_check CHECK (((deliverer_rating >= 1) AND (deliverer_rating <= 5))),
    CONSTRAINT delivery_orders_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'assigned'::character varying, 'picked_up'::character varying, 'in_transit'::character varying, 'delivered'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.delivery_orders OWNER TO postgres;

--
-- Name: TABLE delivery_orders; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.delivery_orders IS 'Commandes de livraison pour la mini-app livreur';


--
-- Name: delivery_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.delivery_orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.delivery_orders_id_seq OWNER TO postgres;

--
-- Name: delivery_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.delivery_orders_id_seq OWNED BY public.delivery_orders.id;


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.favorites (
    id integer NOT NULL,
    user_id uuid,
    product_id integer,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.favorites OWNER TO postgres;

--
-- Name: TABLE favorites; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.favorites IS 'Produits suivis/favoris par les utilisateurs';


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.favorites_id_seq OWNER TO postgres;

--
-- Name: favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.favorites_id_seq OWNED BY public.favorites.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    conversation_id integer NOT NULL,
    sender_id uuid NOT NULL,
    message text NOT NULL,
    reply_to integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    reply_to_id integer,
    type character varying(50) DEFAULT 'text'::character varying,
    metadata jsonb
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- Name: COLUMN messages.type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.messages.type IS 'Type de message: text, media, payment...';


--
-- Name: COLUMN messages.metadata; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.messages.metadata IS 'Données structurées pour les messages spéciaux (paiement, etc)';


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.messages_id_seq OWNER TO postgres;

--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id uuid,
    type character varying(50) NOT NULL,
    title character varying(255) NOT NULL,
    body text,
    data jsonb,
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: TABLE notifications; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.notifications IS 'Notifications push et in-app';


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_items (
    id integer NOT NULL,
    order_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity integer NOT NULL,
    price numeric(10,2) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.order_items OWNER TO postgres;

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.order_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_id_seq OWNER TO postgres;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    shop_id uuid,
    total_price numeric(10,2) NOT NULL,
    status character varying(50) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_id_seq OWNER TO postgres;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    id integer NOT NULL,
    seller_id uuid,
    name character varying(255) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    category character varying(100),
    images text[],
    quantity integer DEFAULT 1,
    status character varying(50) DEFAULT 'active'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    shop_id integer,
    location character varying(100),
    is_negotiable boolean DEFAULT false,
    view_count integer DEFAULT 0,
    like_count integer DEFAULT 0
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_id_seq OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: shops; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shops (
    id integer NOT NULL,
    owner_id uuid,
    name character varying(100) NOT NULL,
    description text,
    logo_url text,
    banner_url text,
    category character varying(50),
    location character varying(100),
    is_verified boolean DEFAULT false,
    rating numeric(2,1) DEFAULT 5.0,
    total_products integer DEFAULT 0,
    total_sales integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.shops OWNER TO postgres;

--
-- Name: TABLE shops; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.shops IS 'Boutiques virtuelles des vendeurs';


--
-- Name: shops_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shops_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shops_id_seq OWNER TO postgres;

--
-- Name: shops_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shops_id_seq OWNED BY public.shops.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone character varying(20) NOT NULL,
    phone_verified boolean DEFAULT false NOT NULL,
    otp_code character varying(10),
    otp_expires_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    is_verified boolean DEFAULT false,
    id_oli character varying(20),
    name character varying(255),
    avatar_url text,
    wallet numeric(10,2) DEFAULT 0,
    country_code character varying(5) DEFAULT '+243'::character varying,
    is_seller boolean DEFAULT false,
    is_deliverer boolean DEFAULT false,
    is_admin boolean DEFAULT false,
    rating numeric(2,1) DEFAULT 5.0,
    total_sales integer DEFAULT 0,
    reward_points integer DEFAULT 0
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: wallet_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wallet_transactions (
    id integer NOT NULL,
    user_id uuid,
    type character varying(20) NOT NULL,
    amount numeric(10,2) NOT NULL,
    balance_after numeric(10,2) NOT NULL,
    reference character varying(100),
    provider character varying(50),
    description text,
    status character varying(20) DEFAULT 'completed'::character varying,
    metadata jsonb,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT wallet_transactions_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'completed'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT wallet_transactions_type_check CHECK (((type)::text = ANY ((ARRAY['deposit'::character varying, 'withdrawal'::character varying, 'payment'::character varying, 'refund'::character varying, 'reward'::character varying, 'transfer'::character varying])::text[])))
);


ALTER TABLE public.wallet_transactions OWNER TO postgres;

--
-- Name: TABLE wallet_transactions; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.wallet_transactions IS 'Historique des transactions du wallet';


--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.wallet_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wallet_transactions_id_seq OWNER TO postgres;

--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.wallet_transactions_id_seq OWNED BY public.wallet_transactions.id;


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: delivery_orders id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_orders ALTER COLUMN id SET DEFAULT nextval('public.delivery_orders_id_seq'::regclass);


--
-- Name: favorites id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites ALTER COLUMN id SET DEFAULT nextval('public.favorites_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: shops id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shops ALTER COLUMN id SET DEFAULT nextval('public.shops_id_seq'::regclass);


--
-- Name: wallet_transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions ALTER COLUMN id SET DEFAULT nextval('public.wallet_transactions_id_seq'::regclass);


--
-- Data for Name: conversations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.conversations (id, user1_id, user2_id, product_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: delivery_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.delivery_orders (id, order_id, deliverer_id, status, pickup_address, delivery_address, pickup_lat, pickup_lng, delivery_lat, delivery_lng, current_lat, current_lng, estimated_time, actual_pickup_time, actual_delivery_time, delivery_fee, deliverer_earnings, deliverer_rating, customer_notes, deliverer_notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: favorites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.favorites (id, user_id, product_id, created_at) FROM stdin;
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (id, conversation_id, sender_id, message, reply_to, created_at, updated_at, reply_to_id, type, metadata) FROM stdin;
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, type, title, body, data, is_read, created_at) FROM stdin;
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_items (id, order_id, product_id, quantity, price, created_at) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (id, user_id, shop_id, total_price, status, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (id, seller_id, name, description, price, category, images, quantity, status, created_at, updated_at, shop_id, location, is_negotiable, view_count, like_count) FROM stdin;
\.


--
-- Data for Name: shops; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shops (id, owner_id, name, description, logo_url, banner_url, category, location, is_verified, rating, total_products, total_sales, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, phone, phone_verified, otp_code, otp_expires_at, created_at, updated_at, is_verified, id_oli, name, avatar_url, wallet, country_code, is_seller, is_deliverer, is_admin, rating, total_sales, reward_points) FROM stdin;
cc8ac04b-e078-4045-bac0-7d25ca9f9810	+33699999999	f	\N	\N	2025-12-31 12:47:29.722546	2025-12-31 12:47:29.722546	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
59906cc5-8349-44bd-abca-ecb9452d821c	+243820000011	f	\N	\N	2026-01-03 07:33:47.63869	2026-01-03 07:33:58.746604	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
3e037158-6e94-4a67-a5f4-010c37a92bb3	+33611112222	f	\N	\N	2025-12-31 12:52:06.328441	2025-12-31 12:52:06.374947	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
e0850d7a-a5ef-48b3-a7eb-8c6976a46081	+243900000020	f	643549	2025-12-31 22:56:32.656	2025-12-31 21:31:42.802696	2025-12-31 21:51:32.659241	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
f67e7ddd-070f-4837-af36-206c0b2e4b63	+243812555555	f	\N	\N	2026-01-03 10:39:36.83359	2026-01-03 10:39:54.474745	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
89498187-5312-4fe1-86dd-1a5ae2c6c551	+243996222222	f	\N	\N	2026-01-04 15:02:35.439366	2026-01-04 15:02:41.641002	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
29316ee3-a3f3-4493-9005-586dab16a608	+243999000000	f	375318	2026-01-02 06:26:50.417	2026-01-02 05:21:50.323407	2026-01-02 05:21:50.422003	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
f51c1979-07fb-4453-bedd-ca2b424ec6d8	+243900000010	t	181474	2026-01-02 07:22:12.812	2025-12-31 21:29:15.241844	2026-01-02 06:17:12.813416	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
0924a793-9052-485d-8c7d-014aa6062569	+243990000000	f	\N	\N	2026-01-06 13:13:30.35429	2026-01-06 13:14:09.181383	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
b3cf06a8-5dd8-403f-9f56-0f82aa0fdc1e	+243999999999	f	\N	\N	2026-01-03 12:54:57.935198	2026-01-07 13:36:58.495318	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
ad62a859-c3e6-4677-a615-3aa4bab5fd01	+243970000001	t	102610	2026-01-02 18:11:17.448	2026-01-01 13:51:37.744923	2026-01-02 17:06:17.448965	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
b8335a51-ca54-4998-a129-83bbabfb9b25	+243992000012	f	\N	\N	2026-01-03 15:15:41.357745	2026-01-03 15:15:49.548068	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
9ceb2017-59bd-4bc7-ae36-4866f0363f9e	+243992000000	f	806789	2026-01-09 14:05:04.836	2026-01-03 11:10:27.042074	2026-01-09 14:00:04.837395	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
8a68ea73-5f70-4169-a02b-989aa2a82279	+243999992222	f	604068	2026-01-03 20:39:32.592	2026-01-03 19:34:32.578644	2026-01-03 19:34:32.593438	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
0d6c8491-50d8-4b72-a7dd-832f48e93ec7	+243820000000	f	\N	\N	2026-01-04 12:59:26.257441	2026-01-04 12:59:35.562188	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
df821fbd-23b6-4fb9-8277-5ddcd5e8ea34	+243992222222	f	\N	\N	2026-01-03 10:52:28.537207	2026-01-03 12:41:53.489303	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
d406e2d0-00ce-4bfe-99f8-fc8bc1cc39d1	+243992000002	f	321752	2026-01-02 19:56:33.529	2026-01-02 18:51:33.49253	2026-01-02 18:51:33.533252	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
ae7af6fc-ec4d-4730-8454-42dd069f95e9	+243992000003	f	\N	\N	2026-01-02 18:55:16.637864	2026-01-02 18:55:27.443272	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
d08dd5ed-6a40-4957-a4f0-b7e41056255a	+243992000005	f	\N	\N	2026-01-02 19:12:00.920449	2026-01-02 19:12:10.123501	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
b65dabef-dc1c-414b-88be-f22612b57b28	+243822222222	f	\N	\N	2026-01-05 08:58:20.839499	2026-01-05 08:58:27.651875	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
8b116413-72c3-4531-9914-7885d761b576	+243992000001	t	\N	\N	2026-01-02 08:45:51.469195	2026-01-05 12:27:49.346667	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0
\.


--
-- Data for Name: wallet_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wallet_transactions (id, user_id, type, amount, balance_after, reference, provider, description, status, metadata, created_at) FROM stdin;
\.


--
-- Name: conversations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.conversations_id_seq', 1, false);


--
-- Name: delivery_orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.delivery_orders_id_seq', 1, false);


--
-- Name: favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.favorites_id_seq', 1, false);


--
-- Name: messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_id_seq', 1, false);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 1, false);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.order_items_id_seq', 1, false);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_id_seq', 1, false);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_id_seq', 1, false);


--
-- Name: shops_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shops_id_seq', 1, false);


--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.wallet_transactions_id_seq', 1, false);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: delivery_orders delivery_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_orders
    ADD CONSTRAINT delivery_orders_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_user_id_product_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_user_id_product_id_key UNIQUE (user_id, product_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: shops shops_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shops
    ADD CONSTRAINT shops_pkey PRIMARY KEY (id);


--
-- Name: users users_id_oli_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_oli_key UNIQUE (id_oli);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wallet_transactions wallet_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_pkey PRIMARY KEY (id);


--
-- Name: idx_conversations_users; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_conversations_users ON public.conversations USING btree (user1_id, user2_id);


--
-- Name: idx_delivery_orders_deliverer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_orders_deliverer ON public.delivery_orders USING btree (deliverer_id);


--
-- Name: idx_delivery_orders_order; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_orders_order ON public.delivery_orders USING btree (order_id);


--
-- Name: idx_delivery_orders_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_orders_status ON public.delivery_orders USING btree (status);


--
-- Name: idx_favorites_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_favorites_user ON public.favorites USING btree (user_id);


--
-- Name: idx_messages_conversation_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_conversation_id ON public.messages USING btree (conversation_id);


--
-- Name: idx_messages_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_type ON public.messages USING btree (type);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id);


--
-- Name: idx_orders_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_user_id ON public.orders USING btree (user_id);


--
-- Name: idx_products_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_category ON public.products USING btree (category);


--
-- Name: idx_products_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_location ON public.products USING btree (location);


--
-- Name: idx_products_seller_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_seller_id ON public.products USING btree (seller_id);


--
-- Name: idx_products_shop; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_shop ON public.products USING btree (shop_id);


--
-- Name: idx_shops_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shops_category ON public.shops USING btree (category);


--
-- Name: idx_shops_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shops_owner ON public.shops USING btree (owner_id);


--
-- Name: idx_users_id_oli; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_id_oli ON public.users USING btree (id_oli);


--
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- Name: idx_wallet_transactions_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_wallet_transactions_type ON public.wallet_transactions USING btree (type);


--
-- Name: idx_wallet_transactions_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_wallet_transactions_user ON public.wallet_transactions USING btree (user_id);


--
-- Name: conversations conversations_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: conversations conversations_user1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_user1_id_fkey FOREIGN KEY (user1_id) REFERENCES public.users(id);


--
-- Name: conversations conversations_user2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_user2_id_fkey FOREIGN KEY (user2_id) REFERENCES public.users(id);


--
-- Name: delivery_orders delivery_orders_deliverer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_orders
    ADD CONSTRAINT delivery_orders_deliverer_id_fkey FOREIGN KEY (deliverer_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: delivery_orders delivery_orders_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_orders
    ADD CONSTRAINT delivery_orders_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: favorites favorites_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: favorites favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: messages messages_reply_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_reply_to_id_fkey FOREIGN KEY (reply_to_id) REFERENCES public.messages(id) ON DELETE SET NULL;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: orders orders_shop_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.users(id);


--
-- Name: orders orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: products products_seller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id);


--
-- Name: shops shops_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shops
    ADD CONSTRAINT shops_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: wallet_transactions wallet_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO oli_user;


--
-- PostgreSQL database dump complete
--

\unrestrict hhWjGIUSxVNbiE07cHuejHVIa2Py4iuA886o9vKgPqHxTNZfkcYqLN00b4jcvVT

