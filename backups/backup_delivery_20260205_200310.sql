--
-- PostgreSQL database dump
--

\restrict fk3ffEX8XBkHyZ4aqEcXUsOsPznYligjmlYvKLxyw0c4FZj4jFzDB7gxWmGWc9I

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


--
-- Name: calculate_overall_trust_score(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_overall_trust_score(p_user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_identity_score INTEGER;
    v_transaction_score INTEGER;
    v_behavior_score INTEGER;
    v_social_score INTEGER;
    v_overall_score INTEGER;
BEGIN
    SELECT identity_score, transaction_score, behavior_score, social_score
    INTO v_identity_score, v_transaction_score, v_behavior_score, v_social_score
    FROM user_trust_scores
    WHERE user_id = p_user_id;
    
    -- Calcul pondéré: identité (40%), transaction (30%), comportement (20%), social (10%)
    v_overall_score := ROUND(
        (v_identity_score * 0.4) + 
        (v_transaction_score * 0.3) + 
        (v_behavior_score * 0.2) + 
        (v_social_score * 0.1)
    );
    
    -- Mise à jour
    UPDATE user_trust_scores
    SET overall_score = v_overall_score, 
        last_calculated_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN v_overall_score;
END;
$$;


ALTER FUNCTION public.calculate_overall_trust_score(p_user_id integer) OWNER TO postgres;

--
-- Name: calculate_overall_trust_score(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_overall_trust_score(p_user_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_identity_score INTEGER;
    v_transaction_score INTEGER;
    v_behavior_score INTEGER;
    v_social_score INTEGER;
    v_overall_score INTEGER;
BEGIN
    SELECT identity_score, transaction_score, behavior_score, social_score
    INTO v_identity_score, v_transaction_score, v_behavior_score, v_social_score
    FROM user_trust_scores
    WHERE user_id = p_user_id;
    
    v_overall_score := ROUND(
        (v_identity_score * 0.4) + 
        (v_transaction_score * 0.3) + 
        (v_behavior_score * 0.2) + 
        (v_social_score * 0.1)
    );
    
    UPDATE user_trust_scores
    SET overall_score = v_overall_score, 
        last_calculated_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN v_overall_score;
END;
$$;


ALTER FUNCTION public.calculate_overall_trust_score(p_user_id uuid) OWNER TO postgres;

--
-- Name: calculate_verification_level(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_verification_level(p_user_id integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_phone_verified BOOLEAN;
    v_email_verified BOOLEAN;
    v_identity_verified BOOLEAN;
    v_address_verified BOOLEAN;
    v_level VARCHAR(20);
BEGIN
    SELECT phone_verified, email_verified, identity_verified, address_verified
    INTO v_phone_verified, v_email_verified, v_identity_verified, v_address_verified
    FROM user_verification_levels
    WHERE user_id = p_user_id;
    
    -- Calcul du niveau
    IF v_identity_verified AND v_address_verified AND v_email_verified THEN
        v_level := 'premium';
    ELSIF v_identity_verified AND v_email_verified THEN
        v_level := 'advanced';
    ELSIF v_identity_verified OR v_email_verified THEN
        v_level := 'intermediate';
    ELSIF v_phone_verified THEN
        v_level := 'basic';
    ELSE
        v_level := 'unverified';
    END IF;
    
    -- Mise à jour
    UPDATE user_verification_levels
    SET verification_level = v_level, updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN v_level;
END;
$$;


ALTER FUNCTION public.calculate_verification_level(p_user_id integer) OWNER TO postgres;

--
-- Name: calculate_verification_level(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_verification_level(p_user_id uuid) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_phone_verified BOOLEAN;
    v_email_verified BOOLEAN;
    v_identity_verified BOOLEAN;
    v_address_verified BOOLEAN;
    v_level VARCHAR(20);
BEGIN
    SELECT phone_verified, email_verified, identity_verified, address_verified
    INTO v_phone_verified, v_email_verified, v_identity_verified, v_address_verified
    FROM user_verification_levels
    WHERE user_id = p_user_id;
    
    IF v_identity_verified AND v_address_verified AND v_email_verified THEN
        v_level := 'premium';
    ELSIF v_identity_verified AND v_email_verified THEN
        v_level := 'advanced';
    ELSIF v_identity_verified OR v_email_verified THEN
        v_level := 'intermediate';
    ELSIF v_phone_verified THEN
        v_level := 'basic';
    ELSE
        v_level := 'unverified';
    END IF;
    
    UPDATE user_verification_levels
    SET verification_level = v_level, updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN v_level;
END;
$$;


ALTER FUNCTION public.calculate_verification_level(p_user_id uuid) OWNER TO postgres;

--
-- Name: trigger_update_trust_score(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trigger_update_trust_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM calculate_overall_trust_score(NEW.user_id);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trigger_update_trust_score() OWNER TO postgres;

--
-- Name: trigger_update_verification_level(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trigger_update_verification_level() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM calculate_verification_level(NEW.user_id);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trigger_update_verification_level() OWNER TO postgres;

--
-- Name: update_deliveries_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_deliveries_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_deliveries_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: addresses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.addresses (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    label character varying(50),
    address text NOT NULL,
    city character varying(100),
    phone character varying(20),
    is_default boolean DEFAULT false,
    latitude numeric(10,8),
    longitude numeric(11,8),
    is_verified boolean DEFAULT false,
    verified_at timestamp without time zone,
    verification_method character varying(50),
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.addresses OWNER TO postgres;

--
-- Name: TABLE addresses; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.addresses IS 'Adresses de livraison des utilisateurs avec GPS et vérification';


--
-- Name: COLUMN addresses.verification_method; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.addresses.verification_method IS 'Méthode: gps, manual, delivery_confirmation';


--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.addresses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.addresses_id_seq OWNER TO postgres;

--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;


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
-- Name: coupon_usages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coupon_usages (
    id integer NOT NULL,
    coupon_id integer NOT NULL,
    user_id uuid NOT NULL,
    order_id integer,
    discount_applied numeric(10,2) NOT NULL,
    used_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.coupon_usages OWNER TO postgres;

--
-- Name: TABLE coupon_usages; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.coupon_usages IS 'Historique d''utilisation des coupons';


--
-- Name: coupon_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.coupon_usages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.coupon_usages_id_seq OWNER TO postgres;

--
-- Name: coupon_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.coupon_usages_id_seq OWNED BY public.coupon_usages.id;


--
-- Name: coupons; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coupons (
    id integer NOT NULL,
    seller_id uuid NOT NULL,
    code character varying(50) NOT NULL,
    type character varying(20) DEFAULT 'percentage'::character varying NOT NULL,
    value numeric(10,2) NOT NULL,
    min_order_amount numeric(10,2) DEFAULT 0,
    max_discount_amount numeric(10,2),
    max_uses integer,
    max_uses_per_user integer DEFAULT 1,
    current_uses integer DEFAULT 0,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_until timestamp without time zone,
    applies_to character varying(20) DEFAULT 'all'::character varying,
    product_ids integer[],
    category_ids integer[],
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.coupons OWNER TO postgres;

--
-- Name: TABLE coupons; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.coupons IS 'Codes promo créés par les vendeurs';


--
-- Name: coupons_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.coupons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.coupons_id_seq OWNER TO postgres;

--
-- Name: coupons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.coupons_id_seq OWNED BY public.coupons.id;


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
    delivery_code character varying(10),
    verified_at timestamp without time zone,
    CONSTRAINT delivery_orders_deliverer_rating_check CHECK (((deliverer_rating >= 1) AND (deliverer_rating <= 5))),
    CONSTRAINT delivery_orders_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'assigned'::character varying, 'picked_up'::character varying, 'in_transit'::character varying, 'delivered'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.delivery_orders OWNER TO postgres;

--
-- Name: TABLE delivery_orders; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.delivery_orders IS 'Commandes de livraison pour la mini-app livreur';


--
-- Name: COLUMN delivery_orders.delivery_code; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.delivery_orders.delivery_code IS 'Code unique à 6 caractères pour validation QR';


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
-- Name: loyalty_points; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loyalty_points (
    id integer NOT NULL,
    seller_id uuid NOT NULL,
    user_id uuid NOT NULL,
    points_balance integer DEFAULT 0,
    total_points_earned integer DEFAULT 0,
    total_points_spent integer DEFAULT 0,
    tier character varying(20) DEFAULT 'bronze'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.loyalty_points OWNER TO postgres;

--
-- Name: TABLE loyalty_points; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.loyalty_points IS 'Solde points fidélité par couple vendeur-client';


--
-- Name: loyalty_points_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loyalty_points_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loyalty_points_id_seq OWNER TO postgres;

--
-- Name: loyalty_points_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loyalty_points_id_seq OWNED BY public.loyalty_points.id;


--
-- Name: loyalty_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loyalty_settings (
    id integer NOT NULL,
    seller_id uuid NOT NULL,
    is_enabled boolean DEFAULT true,
    points_per_dollar numeric(5,2) DEFAULT 1.00,
    points_value numeric(5,4) DEFAULT 0.01,
    min_points_redeem integer DEFAULT 100,
    welcome_bonus integer DEFAULT 0,
    expiry_months integer,
    tier_thresholds jsonb DEFAULT '{"gold": 2000, "silver": 500, "platinum": 5000}'::jsonb,
    tier_multipliers jsonb DEFAULT '{"gold": 1.5, "bronze": 1, "silver": 1.25, "platinum": 2}'::jsonb,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.loyalty_settings OWNER TO postgres;

--
-- Name: TABLE loyalty_settings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.loyalty_settings IS 'Configuration du programme fidélité par vendeur';


--
-- Name: loyalty_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loyalty_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loyalty_settings_id_seq OWNER TO postgres;

--
-- Name: loyalty_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loyalty_settings_id_seq OWNED BY public.loyalty_settings.id;


--
-- Name: loyalty_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loyalty_transactions (
    id integer NOT NULL,
    loyalty_id integer NOT NULL,
    type character varying(20) NOT NULL,
    points integer NOT NULL,
    description text,
    order_id integer,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.loyalty_transactions OWNER TO postgres;

--
-- Name: TABLE loyalty_transactions; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.loyalty_transactions IS 'Historique des mouvements de points';


--
-- Name: loyalty_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loyalty_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loyalty_transactions_id_seq OWNER TO postgres;

--
-- Name: loyalty_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loyalty_transactions_id_seq OWNED BY public.loyalty_transactions.id;


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
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    address_id integer,
    delivery_latitude numeric(10,8),
    delivery_longitude numeric(11,8),
    deliverer_id uuid,
    delivery_status character varying(50) DEFAULT NULL::character varying,
    assigned_to_deliverer_at timestamp without time zone,
    delivery_accepted_at timestamp without time zone,
    delivery_completed_at timestamp without time zone
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: COLUMN orders.address_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.orders.address_id IS 'Référence vers l''adresse de livraison enregistrée';


--
-- Name: COLUMN orders.deliverer_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.orders.deliverer_id IS 'Livreur assigné à cette commande';


--
-- Name: COLUMN orders.delivery_status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.orders.delivery_status IS 'Statut de livraison: pending, assigned, in_transit, delivered';


--
-- Name: COLUMN orders.assigned_to_deliverer_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.orders.assigned_to_deliverer_at IS 'Timestamp d''assignation au livreur';


--
-- Name: COLUMN orders.delivery_accepted_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.orders.delivery_accepted_at IS 'Timestamp d''acceptation par le livreur';


--
-- Name: COLUMN orders.delivery_completed_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.orders.delivery_completed_at IS 'Timestamp de livraison complétée';


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
    like_count integer DEFAULT 0,
    discount_price numeric(10,2),
    discount_start_date timestamp without time zone,
    discount_end_date timestamp without time zone
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
-- Name: user_avatar_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_avatar_history (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    avatar_url text NOT NULL,
    storage_provider character varying(20) DEFAULT 'cloudinary'::character varying,
    file_size_bytes integer,
    mime_type character varying(50),
    is_current boolean DEFAULT false,
    uploaded_at timestamp without time zone DEFAULT now(),
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_avatar_history OWNER TO postgres;

--
-- Name: TABLE user_avatar_history; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_avatar_history IS 'Historique complet des avatars utilisateur avec backup automatique';


--
-- Name: user_avatar_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_avatar_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_avatar_history_id_seq OWNER TO postgres;

--
-- Name: user_avatar_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_avatar_history_id_seq OWNED BY public.user_avatar_history.id;


--
-- Name: user_behavior_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_behavior_events (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    event_type character varying(50) NOT NULL,
    event_category character varying(30),
    event_data jsonb,
    session_id character varying(100),
    device_type character varying(20),
    platform character varying(20),
    ip_address character varying(45),
    user_agent text,
    latitude numeric(10,8),
    longitude numeric(11,8),
    city character varying(100),
    country character varying(3),
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_behavior_events OWNER TO postgres;

--
-- Name: TABLE user_behavior_events; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_behavior_events IS 'Tracking de tous les événements utilisateur pour analyse comportementale';


--
-- Name: user_behavior_events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_behavior_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_behavior_events_id_seq OWNER TO postgres;

--
-- Name: user_behavior_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_behavior_events_id_seq OWNED BY public.user_behavior_events.id;


--
-- Name: user_identity_documents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_identity_documents (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    document_type character varying(50) NOT NULL,
    document_number character varying(100),
    issuing_country character varying(3),
    issue_date date,
    expiry_date date,
    front_image_url text NOT NULL,
    back_image_url text,
    selfie_url text,
    verification_status character varying(20) DEFAULT 'pending'::character varying,
    verified_by uuid,
    verified_at timestamp without time zone,
    rejection_reason text,
    submitted_at timestamp without time zone DEFAULT now(),
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_identity_documents OWNER TO postgres;

--
-- Name: TABLE user_identity_documents; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_identity_documents IS 'Stockage sécurisé des pièces d''identité pour la certification KYC';


--
-- Name: user_identity_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_identity_documents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_identity_documents_id_seq OWNER TO postgres;

--
-- Name: user_identity_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_identity_documents_id_seq OWNED BY public.user_identity_documents.id;


--
-- Name: user_product_views; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_product_views (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    product_id integer NOT NULL,
    viewed_at timestamp without time zone DEFAULT now(),
    session_id character varying(100),
    view_duration_seconds integer,
    source character varying(50),
    device_type character varying(20),
    interactions jsonb,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_product_views OWNER TO postgres;

--
-- Name: TABLE user_product_views; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_product_views IS 'Tracking des produits visités par les utilisateurs';


--
-- Name: COLUMN user_product_views.source; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.user_product_views.source IS 'Source: search, category, recommendation, direct';


--
-- Name: user_product_views_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_product_views_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_product_views_id_seq OWNER TO postgres;

--
-- Name: user_product_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_product_views_id_seq OWNED BY public.user_product_views.id;


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_sessions (
    id integer NOT NULL,
    session_id character varying(100) NOT NULL,
    user_id uuid NOT NULL,
    device_type character varying(20),
    platform character varying(20),
    app_version character varying(20),
    ip_address character varying(45),
    user_agent text,
    latitude numeric(10,8),
    longitude numeric(11,8),
    city character varying(100),
    country character varying(3),
    started_at timestamp without time zone DEFAULT now(),
    last_activity_at timestamp without time zone DEFAULT now(),
    ended_at timestamp without time zone,
    duration_seconds integer,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_sessions OWNER TO postgres;

--
-- Name: TABLE user_sessions; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_sessions IS 'Tracking des sessions utilisateur avec durée et localisation';


--
-- Name: user_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_sessions_id_seq OWNER TO postgres;

--
-- Name: user_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_sessions_id_seq OWNED BY public.user_sessions.id;


--
-- Name: user_trust_scores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_trust_scores (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    identity_score integer DEFAULT 0,
    transaction_score integer DEFAULT 50,
    behavior_score integer DEFAULT 50,
    social_score integer DEFAULT 50,
    overall_score integer DEFAULT 0,
    fraud_risk_level character varying(20) DEFAULT 'low'::character varying,
    is_flagged boolean DEFAULT false,
    flag_reason text,
    score_history jsonb,
    last_calculated_at timestamp without time zone DEFAULT now(),
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_trust_scores OWNER TO postgres;

--
-- Name: TABLE user_trust_scores; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_trust_scores IS 'Scores de confiance et détection de fraude par utilisateur';


--
-- Name: user_trust_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_trust_scores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_trust_scores_id_seq OWNER TO postgres;

--
-- Name: user_trust_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_trust_scores_id_seq OWNED BY public.user_trust_scores.id;


--
-- Name: user_verification_levels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_verification_levels (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    phone_verified boolean DEFAULT false,
    email_verified boolean DEFAULT false,
    identity_verified boolean DEFAULT false,
    address_verified boolean DEFAULT false,
    verification_level character varying(20) DEFAULT 'unverified'::character varying,
    trust_score integer DEFAULT 0,
    phone_verified_at timestamp without time zone,
    email_verified_at timestamp without time zone,
    identity_verified_at timestamp without time zone,
    address_verified_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_verification_levels OWNER TO postgres;

--
-- Name: TABLE user_verification_levels; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_verification_levels IS 'Niveaux de vérification et trust score par utilisateur';


--
-- Name: user_verification_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_verification_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_verification_levels_id_seq OWNER TO postgres;

--
-- Name: user_verification_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_verification_levels_id_seq OWNED BY public.user_verification_levels.id;


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
    reward_points integer DEFAULT 0,
    financial_phone character varying(50),
    financial_phone_verified boolean DEFAULT false,
    financial_phone_provider character varying(30),
    financial_phone_verified_at timestamp without time zone
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: COLUMN users.financial_phone; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.financial_phone IS 'Numéro de téléphone dédié aux opérations Mobile Money (peut être différent du numéro d''authentification)';


--
-- Name: COLUMN users.financial_phone_provider; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.financial_phone_provider IS 'Provider: mpesa, orange_money, airtel_money, etc.';


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
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: coupon_usages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupon_usages ALTER COLUMN id SET DEFAULT nextval('public.coupon_usages_id_seq'::regclass);


--
-- Name: coupons id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupons ALTER COLUMN id SET DEFAULT nextval('public.coupons_id_seq'::regclass);


--
-- Name: delivery_orders id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_orders ALTER COLUMN id SET DEFAULT nextval('public.delivery_orders_id_seq'::regclass);


--
-- Name: favorites id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites ALTER COLUMN id SET DEFAULT nextval('public.favorites_id_seq'::regclass);


--
-- Name: loyalty_points id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_points ALTER COLUMN id SET DEFAULT nextval('public.loyalty_points_id_seq'::regclass);


--
-- Name: loyalty_settings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_settings ALTER COLUMN id SET DEFAULT nextval('public.loyalty_settings_id_seq'::regclass);


--
-- Name: loyalty_transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_transactions ALTER COLUMN id SET DEFAULT nextval('public.loyalty_transactions_id_seq'::regclass);


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
-- Name: user_avatar_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_avatar_history ALTER COLUMN id SET DEFAULT nextval('public.user_avatar_history_id_seq'::regclass);


--
-- Name: user_behavior_events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_behavior_events ALTER COLUMN id SET DEFAULT nextval('public.user_behavior_events_id_seq'::regclass);


--
-- Name: user_identity_documents id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_identity_documents ALTER COLUMN id SET DEFAULT nextval('public.user_identity_documents_id_seq'::regclass);


--
-- Name: user_product_views id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_product_views ALTER COLUMN id SET DEFAULT nextval('public.user_product_views_id_seq'::regclass);


--
-- Name: user_sessions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions ALTER COLUMN id SET DEFAULT nextval('public.user_sessions_id_seq'::regclass);


--
-- Name: user_trust_scores id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_trust_scores ALTER COLUMN id SET DEFAULT nextval('public.user_trust_scores_id_seq'::regclass);


--
-- Name: user_verification_levels id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_verification_levels ALTER COLUMN id SET DEFAULT nextval('public.user_verification_levels_id_seq'::regclass);


--
-- Name: wallet_transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wallet_transactions ALTER COLUMN id SET DEFAULT nextval('public.wallet_transactions_id_seq'::regclass);


--
-- Data for Name: addresses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.addresses (id, user_id, label, address, city, phone, is_default, latitude, longitude, is_verified, verified_at, verification_method, created_at) FROM stdin;
\.


--
-- Data for Name: conversations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.conversations (id, user1_id, user2_id, product_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: coupon_usages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coupon_usages (id, coupon_id, user_id, order_id, discount_applied, used_at) FROM stdin;
\.


--
-- Data for Name: coupons; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coupons (id, seller_id, code, type, value, min_order_amount, max_discount_amount, max_uses, max_uses_per_user, current_uses, valid_from, valid_until, applies_to, product_ids, category_ids, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: delivery_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.delivery_orders (id, order_id, deliverer_id, status, pickup_address, delivery_address, pickup_lat, pickup_lng, delivery_lat, delivery_lng, current_lat, current_lng, estimated_time, actual_pickup_time, actual_delivery_time, delivery_fee, deliverer_earnings, deliverer_rating, customer_notes, deliverer_notes, created_at, updated_at, delivery_code, verified_at) FROM stdin;
\.


--
-- Data for Name: favorites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.favorites (id, user_id, product_id, created_at) FROM stdin;
\.


--
-- Data for Name: loyalty_points; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loyalty_points (id, seller_id, user_id, points_balance, total_points_earned, total_points_spent, tier, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: loyalty_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loyalty_settings (id, seller_id, is_enabled, points_per_dollar, points_value, min_points_redeem, welcome_bonus, expiry_months, tier_thresholds, tier_multipliers, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: loyalty_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loyalty_transactions (id, loyalty_id, type, points, description, order_id, created_at) FROM stdin;
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

COPY public.orders (id, user_id, shop_id, total_price, status, created_at, updated_at, address_id, delivery_latitude, delivery_longitude, deliverer_id, delivery_status, assigned_to_deliverer_at, delivery_accepted_at, delivery_completed_at) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (id, seller_id, name, description, price, category, images, quantity, status, created_at, updated_at, shop_id, location, is_negotiable, view_count, like_count, discount_price, discount_start_date, discount_end_date) FROM stdin;
\.


--
-- Data for Name: shops; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shops (id, owner_id, name, description, logo_url, banner_url, category, location, is_verified, rating, total_products, total_sales, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_avatar_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_avatar_history (id, user_id, avatar_url, storage_provider, file_size_bytes, mime_type, is_current, uploaded_at, created_at) FROM stdin;
\.


--
-- Data for Name: user_behavior_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_behavior_events (id, user_id, event_type, event_category, event_data, session_id, device_type, platform, ip_address, user_agent, latitude, longitude, city, country, created_at) FROM stdin;
\.


--
-- Data for Name: user_identity_documents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_identity_documents (id, user_id, document_type, document_number, issuing_country, issue_date, expiry_date, front_image_url, back_image_url, selfie_url, verification_status, verified_by, verified_at, rejection_reason, submitted_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_product_views; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_product_views (id, user_id, product_id, viewed_at, session_id, view_duration_seconds, source, device_type, interactions, created_at) FROM stdin;
\.


--
-- Data for Name: user_sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_sessions (id, session_id, user_id, device_type, platform, app_version, ip_address, user_agent, latitude, longitude, city, country, started_at, last_activity_at, ended_at, duration_seconds, created_at) FROM stdin;
\.


--
-- Data for Name: user_trust_scores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_trust_scores (id, user_id, identity_score, transaction_score, behavior_score, social_score, overall_score, fraud_risk_level, is_flagged, flag_reason, score_history, last_calculated_at, created_at, updated_at) FROM stdin;
1	cc8ac04b-e078-4045-bac0-7d25ca9f9810	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
2	59906cc5-8349-44bd-abca-ecb9452d821c	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
3	3e037158-6e94-4a67-a5f4-010c37a92bb3	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
4	e0850d7a-a5ef-48b3-a7eb-8c6976a46081	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
5	f67e7ddd-070f-4837-af36-206c0b2e4b63	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
6	89498187-5312-4fe1-86dd-1a5ae2c6c551	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
7	29316ee3-a3f3-4493-9005-586dab16a608	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
8	f51c1979-07fb-4453-bedd-ca2b424ec6d8	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
9	0924a793-9052-485d-8c7d-014aa6062569	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
10	b3cf06a8-5dd8-403f-9f56-0f82aa0fdc1e	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
11	ad62a859-c3e6-4677-a615-3aa4bab5fd01	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
12	b8335a51-ca54-4998-a129-83bbabfb9b25	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
13	9ceb2017-59bd-4bc7-ae36-4866f0363f9e	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
14	8a68ea73-5f70-4169-a02b-989aa2a82279	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
15	25c36198-7b59-41db-8000-6f63e0d128dd	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
16	0d6c8491-50d8-4b72-a7dd-832f48e93ec7	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
17	bde1f3d5-ab87-4179-9b99-04b57eb4f7b0	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
18	df821fbd-23b6-4fb9-8277-5ddcd5e8ea34	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
19	d406e2d0-00ce-4bfe-99f8-fc8bc1cc39d1	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
20	ae7af6fc-ec4d-4730-8454-42dd069f95e9	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
21	d08dd5ed-6a40-4957-a4f0-b7e41056255a	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
22	b65dabef-dc1c-414b-88be-f22612b57b28	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
23	8b116413-72c3-4531-9914-7885d761b576	0	50	50	50	37	low	f	\N	\N	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956	2026-01-25 08:08:46.448956
\.


--
-- Data for Name: user_verification_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_verification_levels (id, user_id, phone_verified, email_verified, identity_verified, address_verified, verification_level, trust_score, phone_verified_at, email_verified_at, identity_verified_at, address_verified_at, created_at, updated_at) FROM stdin;
1	cc8ac04b-e078-4045-bac0-7d25ca9f9810	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
2	59906cc5-8349-44bd-abca-ecb9452d821c	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
3	3e037158-6e94-4a67-a5f4-010c37a92bb3	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
4	e0850d7a-a5ef-48b3-a7eb-8c6976a46081	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
5	f67e7ddd-070f-4837-af36-206c0b2e4b63	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
6	89498187-5312-4fe1-86dd-1a5ae2c6c551	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
7	29316ee3-a3f3-4493-9005-586dab16a608	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
8	f51c1979-07fb-4453-bedd-ca2b424ec6d8	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
9	0924a793-9052-485d-8c7d-014aa6062569	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
10	b3cf06a8-5dd8-403f-9f56-0f82aa0fdc1e	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
11	ad62a859-c3e6-4677-a615-3aa4bab5fd01	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
12	b8335a51-ca54-4998-a129-83bbabfb9b25	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
13	9ceb2017-59bd-4bc7-ae36-4866f0363f9e	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
14	8a68ea73-5f70-4169-a02b-989aa2a82279	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
15	25c36198-7b59-41db-8000-6f63e0d128dd	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
16	0d6c8491-50d8-4b72-a7dd-832f48e93ec7	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
17	bde1f3d5-ab87-4179-9b99-04b57eb4f7b0	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
18	df821fbd-23b6-4fb9-8277-5ddcd5e8ea34	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
19	d406e2d0-00ce-4bfe-99f8-fc8bc1cc39d1	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
20	ae7af6fc-ec4d-4730-8454-42dd069f95e9	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
21	d08dd5ed-6a40-4957-a4f0-b7e41056255a	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
22	b65dabef-dc1c-414b-88be-f22612b57b28	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
23	8b116413-72c3-4531-9914-7885d761b576	t	f	f	f	basic	0	\N	\N	\N	\N	2026-01-25 08:08:46.433555	2026-01-25 08:08:46.433555
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, phone, phone_verified, otp_code, otp_expires_at, created_at, updated_at, is_verified, id_oli, name, avatar_url, wallet, country_code, is_seller, is_deliverer, is_admin, rating, total_sales, reward_points, financial_phone, financial_phone_verified, financial_phone_provider, financial_phone_verified_at) FROM stdin;
cc8ac04b-e078-4045-bac0-7d25ca9f9810	+33699999999	f	\N	\N	2025-12-31 12:47:29.722546	2025-12-31 12:47:29.722546	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
59906cc5-8349-44bd-abca-ecb9452d821c	+243820000011	f	\N	\N	2026-01-03 07:33:47.63869	2026-01-03 07:33:58.746604	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
3e037158-6e94-4a67-a5f4-010c37a92bb3	+33611112222	f	\N	\N	2025-12-31 12:52:06.328441	2025-12-31 12:52:06.374947	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
e0850d7a-a5ef-48b3-a7eb-8c6976a46081	+243900000020	f	643549	2025-12-31 22:56:32.656	2025-12-31 21:31:42.802696	2025-12-31 21:51:32.659241	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
f67e7ddd-070f-4837-af36-206c0b2e4b63	+243812555555	f	\N	\N	2026-01-03 10:39:36.83359	2026-01-03 10:39:54.474745	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
89498187-5312-4fe1-86dd-1a5ae2c6c551	+243996222222	f	\N	\N	2026-01-04 15:02:35.439366	2026-01-04 15:02:41.641002	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
29316ee3-a3f3-4493-9005-586dab16a608	+243999000000	f	375318	2026-01-02 06:26:50.417	2026-01-02 05:21:50.323407	2026-01-02 05:21:50.422003	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
f51c1979-07fb-4453-bedd-ca2b424ec6d8	+243900000010	t	181474	2026-01-02 07:22:12.812	2025-12-31 21:29:15.241844	2026-01-02 06:17:12.813416	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
0924a793-9052-485d-8c7d-014aa6062569	+243990000000	f	\N	\N	2026-01-06 13:13:30.35429	2026-01-06 13:14:09.181383	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
b3cf06a8-5dd8-403f-9f56-0f82aa0fdc1e	+243999999999	f	\N	\N	2026-01-03 12:54:57.935198	2026-01-07 13:36:58.495318	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
ad62a859-c3e6-4677-a615-3aa4bab5fd01	+243970000001	t	102610	2026-01-02 18:11:17.448	2026-01-01 13:51:37.744923	2026-01-02 17:06:17.448965	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
b8335a51-ca54-4998-a129-83bbabfb9b25	+243992000012	f	\N	\N	2026-01-03 15:15:41.357745	2026-01-03 15:15:49.548068	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
9ceb2017-59bd-4bc7-ae36-4866f0363f9e	+243992000000	f	806789	2026-01-09 14:05:04.836	2026-01-03 11:10:27.042074	2026-01-09 14:00:04.837395	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
8a68ea73-5f70-4169-a02b-989aa2a82279	+243999992222	f	604068	2026-01-03 20:39:32.592	2026-01-03 19:34:32.578644	2026-01-03 19:34:32.593438	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
25c36198-7b59-41db-8000-6f63e0d128dd	+243999888777	f	502605	2026-01-10 15:04:07.118	2026-01-10 14:59:07.077402	2026-01-10 14:59:07.122292	f	OLI-8777-2441	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
0d6c8491-50d8-4b72-a7dd-832f48e93ec7	+243820000000	f	\N	\N	2026-01-04 12:59:26.257441	2026-01-04 12:59:35.562188	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
bde1f3d5-ab87-4179-9b99-04b57eb4f7b0	+243123456789	f	297376	2026-01-12 16:14:31	2026-01-12 16:09:30.941138	2026-01-12 16:09:31.001472	f	OLI-6789-2895	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
df821fbd-23b6-4fb9-8277-5ddcd5e8ea34	+243992222222	f	\N	\N	2026-01-03 10:52:28.537207	2026-01-03 12:41:53.489303	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
d406e2d0-00ce-4bfe-99f8-fc8bc1cc39d1	+243992000002	f	321752	2026-01-02 19:56:33.529	2026-01-02 18:51:33.49253	2026-01-02 18:51:33.533252	f	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
ae7af6fc-ec4d-4730-8454-42dd069f95e9	+243992000003	f	\N	\N	2026-01-02 18:55:16.637864	2026-01-02 18:55:27.443272	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
d08dd5ed-6a40-4957-a4f0-b7e41056255a	+243992000005	f	\N	\N	2026-01-02 19:12:00.920449	2026-01-02 19:12:10.123501	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
b65dabef-dc1c-414b-88be-f22612b57b28	+243822222222	f	\N	\N	2026-01-05 08:58:20.839499	2026-01-05 08:58:27.651875	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
8b116413-72c3-4531-9914-7885d761b576	+243992000001	t	\N	\N	2026-01-02 08:45:51.469195	2026-01-05 12:27:49.346667	t	\N	\N	\N	0.00	+243	f	f	f	5.0	0	0	\N	f	\N	\N
\.


--
-- Data for Name: wallet_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wallet_transactions (id, user_id, type, amount, balance_after, reference, provider, description, status, metadata, created_at) FROM stdin;
\.


--
-- Name: addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.addresses_id_seq', 1, false);


--
-- Name: conversations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.conversations_id_seq', 1, false);


--
-- Name: coupon_usages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.coupon_usages_id_seq', 1, false);


--
-- Name: coupons_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.coupons_id_seq', 1, false);


--
-- Name: delivery_orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.delivery_orders_id_seq', 1, false);


--
-- Name: favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.favorites_id_seq', 1, false);


--
-- Name: loyalty_points_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loyalty_points_id_seq', 1, false);


--
-- Name: loyalty_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loyalty_settings_id_seq', 1, false);


--
-- Name: loyalty_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loyalty_transactions_id_seq', 1, false);


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
-- Name: user_avatar_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_avatar_history_id_seq', 1, false);


--
-- Name: user_behavior_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_behavior_events_id_seq', 1, false);


--
-- Name: user_identity_documents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_identity_documents_id_seq', 1, false);


--
-- Name: user_product_views_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_product_views_id_seq', 1, false);


--
-- Name: user_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_sessions_id_seq', 1, false);


--
-- Name: user_trust_scores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_trust_scores_id_seq', 23, true);


--
-- Name: user_verification_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_verification_levels_id_seq', 23, true);


--
-- Name: wallet_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.wallet_transactions_id_seq', 1, false);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: coupon_usages coupon_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupon_usages
    ADD CONSTRAINT coupon_usages_pkey PRIMARY KEY (id);


--
-- Name: coupons coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_pkey PRIMARY KEY (id);


--
-- Name: coupons coupons_seller_id_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_seller_id_code_key UNIQUE (seller_id, code);


--
-- Name: delivery_orders delivery_orders_delivery_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_orders
    ADD CONSTRAINT delivery_orders_delivery_code_key UNIQUE (delivery_code);


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
-- Name: loyalty_points loyalty_points_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_points
    ADD CONSTRAINT loyalty_points_pkey PRIMARY KEY (id);


--
-- Name: loyalty_points loyalty_points_seller_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_points
    ADD CONSTRAINT loyalty_points_seller_id_user_id_key UNIQUE (seller_id, user_id);


--
-- Name: loyalty_settings loyalty_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_settings
    ADD CONSTRAINT loyalty_settings_pkey PRIMARY KEY (id);


--
-- Name: loyalty_settings loyalty_settings_seller_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_settings
    ADD CONSTRAINT loyalty_settings_seller_id_key UNIQUE (seller_id);


--
-- Name: loyalty_transactions loyalty_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_transactions
    ADD CONSTRAINT loyalty_transactions_pkey PRIMARY KEY (id);


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
-- Name: user_identity_documents unique_user_document; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_identity_documents
    ADD CONSTRAINT unique_user_document UNIQUE (user_id, document_type);


--
-- Name: user_avatar_history user_avatar_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_avatar_history
    ADD CONSTRAINT user_avatar_history_pkey PRIMARY KEY (id);


--
-- Name: user_behavior_events user_behavior_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_behavior_events
    ADD CONSTRAINT user_behavior_events_pkey PRIMARY KEY (id);


--
-- Name: user_identity_documents user_identity_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_identity_documents
    ADD CONSTRAINT user_identity_documents_pkey PRIMARY KEY (id);


--
-- Name: user_product_views user_product_views_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_product_views
    ADD CONSTRAINT user_product_views_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_session_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_session_id_key UNIQUE (session_id);


--
-- Name: user_trust_scores user_trust_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_trust_scores
    ADD CONSTRAINT user_trust_scores_pkey PRIMARY KEY (id);


--
-- Name: user_trust_scores user_trust_scores_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_trust_scores
    ADD CONSTRAINT user_trust_scores_user_id_key UNIQUE (user_id);


--
-- Name: user_verification_levels user_verification_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_verification_levels
    ADD CONSTRAINT user_verification_levels_pkey PRIMARY KEY (id);


--
-- Name: user_verification_levels user_verification_levels_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_verification_levels
    ADD CONSTRAINT user_verification_levels_user_id_key UNIQUE (user_id);


--
-- Name: users users_financial_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_financial_phone_key UNIQUE (financial_phone);


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
-- Name: idx_addresses_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_addresses_user_id ON public.addresses USING btree (user_id);


--
-- Name: idx_avatar_history_current; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_avatar_history_current ON public.user_avatar_history USING btree (user_id) WHERE (is_current = true);


--
-- Name: idx_avatar_history_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_avatar_history_user ON public.user_avatar_history USING btree (user_id, uploaded_at DESC);


--
-- Name: idx_behavior_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_behavior_category ON public.user_behavior_events USING btree (event_category);


--
-- Name: idx_behavior_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_behavior_session ON public.user_behavior_events USING btree (session_id);


--
-- Name: idx_behavior_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_behavior_type ON public.user_behavior_events USING btree (event_type);


--
-- Name: idx_behavior_user_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_behavior_user_time ON public.user_behavior_events USING btree (user_id, created_at DESC);


--
-- Name: idx_conversations_users; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_conversations_users ON public.conversations USING btree (user1_id, user2_id);


--
-- Name: idx_coupon_usages_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_coupon_usages_user ON public.coupon_usages USING btree (user_id);


--
-- Name: idx_coupons_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_coupons_active ON public.coupons USING btree (is_active, valid_from, valid_until);


--
-- Name: idx_coupons_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_coupons_code ON public.coupons USING btree (code);


--
-- Name: idx_coupons_seller; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_coupons_seller ON public.coupons USING btree (seller_id);


--
-- Name: idx_delivery_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_delivery_code ON public.delivery_orders USING btree (delivery_code);


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
-- Name: idx_identity_docs_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_identity_docs_status ON public.user_identity_documents USING btree (verification_status);


--
-- Name: idx_identity_docs_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_identity_docs_user ON public.user_identity_documents USING btree (user_id);


--
-- Name: idx_loyalty_points_seller; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loyalty_points_seller ON public.loyalty_points USING btree (seller_id);


--
-- Name: idx_loyalty_points_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loyalty_points_user ON public.loyalty_points USING btree (user_id);


--
-- Name: idx_loyalty_transactions_loyalty; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loyalty_transactions_loyalty ON public.loyalty_transactions USING btree (loyalty_id);


--
-- Name: idx_messages_conversation_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_conversation_id ON public.messages USING btree (conversation_id);


--
-- Name: idx_messages_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_type ON public.messages USING btree (type);


--
-- Name: idx_notifications_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_created ON public.notifications USING btree (created_at DESC);


--
-- Name: idx_notifications_unread; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_unread ON public.notifications USING btree (user_id, is_read);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id);


--
-- Name: idx_orders_deliverer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_deliverer ON public.orders USING btree (deliverer_id);


--
-- Name: idx_orders_delivery_pending; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_delivery_pending ON public.orders USING btree (status, delivery_status) WHERE (((status)::text = 'paid'::text) AND (delivery_status IS NULL));


--
-- Name: idx_orders_delivery_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_delivery_status ON public.orders USING btree (delivery_status);


--
-- Name: idx_orders_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_user_id ON public.orders USING btree (user_id);


--
-- Name: idx_products_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_category ON public.products USING btree (category);


--
-- Name: idx_products_discount_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_discount_dates ON public.products USING btree (discount_start_date, discount_end_date);


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
-- Name: idx_sessions_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sessions_active ON public.user_sessions USING btree (user_id) WHERE (ended_at IS NULL);


--
-- Name: idx_sessions_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sessions_user ON public.user_sessions USING btree (user_id, started_at DESC);


--
-- Name: idx_shops_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shops_category ON public.shops USING btree (category);


--
-- Name: idx_shops_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shops_owner ON public.shops USING btree (owner_id);


--
-- Name: idx_trust_flagged; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trust_flagged ON public.user_trust_scores USING btree (is_flagged) WHERE (is_flagged = true);


--
-- Name: idx_trust_fraud_risk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trust_fraud_risk ON public.user_trust_scores USING btree (fraud_risk_level);


--
-- Name: idx_trust_overall_score; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trust_overall_score ON public.user_trust_scores USING btree (overall_score DESC);


--
-- Name: idx_trust_score; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_trust_score ON public.user_verification_levels USING btree (trust_score DESC);


--
-- Name: idx_user_product_views_product; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_product_views_product ON public.user_product_views USING btree (product_id, viewed_at DESC);


--
-- Name: idx_user_product_views_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_product_views_unique ON public.user_product_views USING btree (user_id, product_id);


--
-- Name: idx_user_product_views_user_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_product_views_user_date ON public.user_product_views USING btree (user_id, viewed_at DESC);


--
-- Name: idx_users_financial_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_financial_phone ON public.users USING btree (financial_phone) WHERE (financial_phone IS NOT NULL);


--
-- Name: idx_users_id_oli; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_id_oli ON public.users USING btree (id_oli);


--
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- Name: idx_verification_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_verification_level ON public.user_verification_levels USING btree (verification_level);


--
-- Name: idx_wallet_transactions_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_wallet_transactions_type ON public.wallet_transactions USING btree (type);


--
-- Name: idx_wallet_transactions_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_wallet_transactions_user ON public.wallet_transactions USING btree (user_id);


--
-- Name: user_trust_scores trg_update_trust_score; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_trust_score AFTER UPDATE ON public.user_trust_scores FOR EACH ROW WHEN (((old.identity_score IS DISTINCT FROM new.identity_score) OR (old.transaction_score IS DISTINCT FROM new.transaction_score) OR (old.behavior_score IS DISTINCT FROM new.behavior_score) OR (old.social_score IS DISTINCT FROM new.social_score))) EXECUTE FUNCTION public.trigger_update_trust_score();


--
-- Name: user_verification_levels trg_update_verification_level; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_verification_level AFTER UPDATE ON public.user_verification_levels FOR EACH ROW WHEN (((old.phone_verified IS DISTINCT FROM new.phone_verified) OR (old.email_verified IS DISTINCT FROM new.email_verified) OR (old.identity_verified IS DISTINCT FROM new.identity_verified) OR (old.address_verified IS DISTINCT FROM new.address_verified))) EXECUTE FUNCTION public.trigger_update_verification_level();


--
-- Name: addresses addresses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: coupon_usages coupon_usages_coupon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupon_usages
    ADD CONSTRAINT coupon_usages_coupon_id_fkey FOREIGN KEY (coupon_id) REFERENCES public.coupons(id) ON DELETE CASCADE;


--
-- Name: coupon_usages coupon_usages_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupon_usages
    ADD CONSTRAINT coupon_usages_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;


--
-- Name: coupon_usages coupon_usages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupon_usages
    ADD CONSTRAINT coupon_usages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: coupons coupons_seller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: loyalty_points loyalty_points_seller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_points
    ADD CONSTRAINT loyalty_points_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: loyalty_points loyalty_points_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_points
    ADD CONSTRAINT loyalty_points_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: loyalty_settings loyalty_settings_seller_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_settings
    ADD CONSTRAINT loyalty_settings_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: loyalty_transactions loyalty_transactions_loyalty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_transactions
    ADD CONSTRAINT loyalty_transactions_loyalty_id_fkey FOREIGN KEY (loyalty_id) REFERENCES public.loyalty_points(id) ON DELETE CASCADE;


--
-- Name: loyalty_transactions loyalty_transactions_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_transactions
    ADD CONSTRAINT loyalty_transactions_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;


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
-- Name: orders orders_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id);


--
-- Name: orders orders_deliverer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_deliverer_id_fkey FOREIGN KEY (deliverer_id) REFERENCES public.users(id) ON DELETE SET NULL;


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
-- Name: user_avatar_history user_avatar_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_avatar_history
    ADD CONSTRAINT user_avatar_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_behavior_events user_behavior_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_behavior_events
    ADD CONSTRAINT user_behavior_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_identity_documents user_identity_documents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_identity_documents
    ADD CONSTRAINT user_identity_documents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_identity_documents user_identity_documents_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_identity_documents
    ADD CONSTRAINT user_identity_documents_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id);


--
-- Name: user_product_views user_product_views_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_product_views
    ADD CONSTRAINT user_product_views_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: user_product_views user_product_views_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_product_views
    ADD CONSTRAINT user_product_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_trust_scores user_trust_scores_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_trust_scores
    ADD CONSTRAINT user_trust_scores_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_verification_levels user_verification_levels_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_verification_levels
    ADD CONSTRAINT user_verification_levels_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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

\unrestrict fk3ffEX8XBkHyZ4aqEcXUsOsPznYligjmlYvKLxyw0c4FZj4jFzDB7gxWmGWc9I

