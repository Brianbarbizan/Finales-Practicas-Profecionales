--
-- PostgreSQL database dump
--

-- Dumped from database version 9.1.2
-- Dumped by pg_dump version 14.2

-- Started on 2022-10-04 19:44:33

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'LATIN1';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 2091 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 8 (class 2615 OID 27934)
-- Name: public_auditoria; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public_auditoria;


ALTER SCHEMA public_auditoria OWNER TO postgres;

--
-- TOC entry 576 (class 1247 OID 27302)
-- Name: t_ventas_detalle; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.t_ventas_detalle AS (
	id_presentacion integer,
	cantidad integer,
	fecha_vencimiento date,
	id_articulo integer
);


ALTER TYPE public.t_ventas_detalle OWNER TO postgres;

--
-- TOC entry 208 (class 1255 OID 27303)
-- Name: actualizar_stock(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.actualizar_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

        cantidad1       integer;
        cantidad2       integer;
        diferencia	integer;
	idarticulo      integer;
	lote	        varchar;

  BEGIN

       cantidad1  = NEW.cantidad;
       cantidad2  = OLD.cantidad;
       idarticulo = NEW.id_articulo; 
       lote = NEW.nro_lote; 

       IF (cantidad1<>cantidad2) THEN
		IF (cantidad1>cantidad2) THEN
			diferencia=cantidad1-cantidad2;
			UPDATE presentaciones SET cantidad = cantidad + diferencia
			WHERE id_articulo = idarticulo and nro_lote=lote;  
		ELSE
			diferencia=cantidad2-cantidad1;
			UPDATE presentaciones SET cantidad = cantidad - diferencia
			WHERE id_articulo = idarticulo and nro_lote=lote;
		END IF;	
       END IF;

       RETURN NULL;

  END;

$$;


ALTER FUNCTION public.actualizar_stock() OWNER TO postgres;

--
-- TOC entry 209 (class 1255 OID 27304)
-- Name: actualizar_stock_ventas(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.actualizar_stock_ventas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

        cantidad1       integer;
        cantidad2       integer;
        diferencia	integer;
	idpresentacion  integer;

  BEGIN

       cantidad1  = NEW.cantidad;
       cantidad2  = OLD.cantidad;
       idpresentacion = NEW.id_presentacion; 

       IF (cantidad1<>cantidad2) THEN
		IF (cantidad1>cantidad2) THEN
			diferencia=cantidad1-cantidad2;
			UPDATE presentaciones SET cantidad = cantidad - diferencia
			WHERE id = idpresentacion;  
		ELSE
			diferencia=cantidad2-cantidad1;
			UPDATE presentaciones SET cantidad = cantidad + diferencia
			WHERE id = idpresentacion;
		END IF;	
       END IF;

       RETURN NULL;

  END;

$$;


ALTER FUNCTION public.actualizar_stock_ventas() OWNER TO postgres;

--
-- TOC entry 210 (class 1255 OID 27305)
-- Name: armar_salida_pedido_interno(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.armar_salida_pedido_interno(_id_pedido_interno integer) RETURNS SETOF public.t_ventas_detalle
    LANGUAGE plpgsql
    AS $$
DECLARE     
  pedido record;      --guarda el pedido
  lote record;      --guarda los lotes de un articulo
  _cantidad_pedida integer; --cantidad pedida de un articulo
  _cant_salida_lote integer;  --cantidad de articulos a sacar del lote
  fila t_ventas_detalle%rowtype;  --para armar las filas que retorna la funcion
  
BEGIN 
    
  --recorro cada uno de los articulos del pedido
  for pedido in SELECT * FROM pedidos_internos_detalle WHERE id_pedidos_cabecera =_id_pedido_interno
  loop          
    _cantidad_pedida = pedido.cantidad;
    --select * from ventas_detalle 
    --select * from presentaciones
    --recorro los lotes
    for lote in SELECT * FROM presentaciones WHERE id_articulo=pedido.id_articulo and cantidad>0 ORDER BY fecha_vencimiento ASC
    loop      
      if _cantidad_pedida>0 then --si todavia no llego a la cantidad del pedido busco en otro lote
              
        if _cantidad_pedida>lote.cantidad then --si la cantidad del pedido es mayor a la del lote
          _cant_salida_lote = lote.cantidad;
        else          --si el stock del lote es mayor a la del pedido
          _cant_salida_lote = _cantidad_pedida;
        end if;
        fila.id_articulo = pedido.id_articulo;    
        fila.id_presentacion = lote.id;
        fila.cantidad = _cant_salida_lote;
        fila.fecha_vencimiento = lote.fecha_vencimiento;
        return next fila;
        _cantidad_pedida = _cantidad_pedida-_cant_salida_lote; --calculo el nuevo faltante
      else
        exit; --si ya alcance la cantidad pedida salgo del loop
      end if;
    end loop;   
  end loop;       

  RETURN;
END;
$$;


ALTER FUNCTION public.armar_salida_pedido_interno(_id_pedido_interno integer) OWNER TO postgres;

--
-- TOC entry 211 (class 1255 OID 27306)
-- Name: bajar_stock(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.bajar_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE
        cant	        integer;
        lote		varchar;
	idarticulo      integer;

  BEGIN

	cant = OLD.cantidad;
	idarticulo = OLD.id_articulo;
	lote = OLD.nro_lote;

	UPDATE presentaciones SET cantidad = cantidad - cant
	WHERE id_articulo = idarticulo and nro_lote=lote;

	RETURN NULL;

  END;

$$;


ALTER FUNCTION public.bajar_stock() OWNER TO postgres;

--
-- TOC entry 212 (class 1255 OID 27307)
-- Name: bajar_stock_ventas(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.bajar_stock_ventas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE
        cant	        integer;
	idpresentacion  integer;

  BEGIN

	cant = NEW.cantidad;
	idpresentacion = NEW.id_presentacion;

	UPDATE presentaciones SET cantidad = cantidad - cant
	WHERE id = idpresentacion;

	RETURN NULL;

  END;

$$;


ALTER FUNCTION public.bajar_stock_ventas() OWNER TO postgres;

--
-- TOC entry 215 (class 1255 OID 27935)
-- Name: recuperar_schema_temp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.recuperar_schema_temp() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
			DECLARE
			   schemas varchar;
			   pos_inicial int4;
			   pos_final int4;
			   schema_temp varchar;
			BEGIN
			   schema_temp := '';
			   SELECT INTO schemas current_schemas(true);
			   SELECT INTO pos_inicial strpos(schemas, 'pg_temp');
			   IF (pos_inicial > 0) THEN
			      SELECT INTO pos_final strpos(schemas, ',');
			      SELECT INTO schema_temp substr(schemas, pos_inicial, pos_final - pos_inicial);
			   END IF;
			   RETURN schema_temp;
			END;
			$$;


ALTER FUNCTION public.recuperar_schema_temp() OWNER TO postgres;

--
-- TOC entry 213 (class 1255 OID 27308)
-- Name: subir_stock(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.subir_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

        cant        integer;
        idarticulo  integer;
        lote      varchar;
        resultado   integer;
        proveedor   integer;
        ubicacion   integer;
        precio      integer;

  BEGIN
        cant  = NEW.cantidad;
        idarticulo = NEW.id_articulo;
        lote = NEW.nro_lote;
        ubicacion = NEW.id_ubicacion;
        precio = NEW.precio; 

  proveedor := (SELECT id_proveedor FROM compras_cabecera WHERE id=NEW.id_compras_cabecera);
  resultado := (SELECT 1 as contador FROM presentaciones WHERE id_articulo = idarticulo and nro_lote=lote);

  
  IF resultado>0 THEN
    UPDATE presentaciones SET cantidad = cantidad + cant
    WHERE id_articulo = idarticulo and nro_lote=lote;    
  ELSE
    INSERT INTO presentaciones (id_articulo,nro_lote,cantidad,fecha_vencimiento,id_proveedor,id_ubicacion,precio,id_compras_cabecera,codigo_proveedor)
    VALUES (NEW.id_articulo,NEW.nro_lote,NEW.cantidad,NEW.fecha_vencimiento,proveedor,NEW.id_ubicacion,NEW.precio,NEW.id_compras_cabecera,NEW.codigo_proveedor);
  END IF;

  RETURN NULL;
  END;

$$;


ALTER FUNCTION public.subir_stock() OWNER TO postgres;

--
-- TOC entry 214 (class 1255 OID 27309)
-- Name: subir_stock_ventas(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.subir_stock_ventas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

        cant        	integer;
        idpresentacion  integer;

  BEGIN
        cant  = OLD.cantidad;
        idpresentacion = OLD.id_presentacion;

        UPDATE presentaciones SET cantidad = cantidad + cant
	WHERE id = idpresentacion;

	RETURN NULL;
  END;

$$;


ALTER FUNCTION public.subir_stock_ventas() OWNER TO postgres;

--
-- TOC entry 216 (class 1255 OID 27969)
-- Name: sp_alumnos(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_alumnos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_alumnos (id, id_tipo_documento, numero_documento, descripcion, direccion, telefono, mail, fecha_nacimiento, legajo, id_localidad, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.id_tipo_documento, NEW.numero_documento, NEW.descripcion, NEW.direccion, NEW.telefono, NEW.mail, NEW.fecha_nacimiento, NEW.legajo, NEW.id_localidad, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_alumnos (id, id_tipo_documento, numero_documento, descripcion, direccion, telefono, mail, fecha_nacimiento, legajo, id_localidad, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.id_tipo_documento, OLD.numero_documento, OLD.descripcion, OLD.direccion, OLD.telefono, OLD.mail, OLD.fecha_nacimiento, OLD.legajo, OLD.id_localidad, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_alumnos() OWNER TO postgres;

--
-- TOC entry 217 (class 1255 OID 27970)
-- Name: sp_asuetos(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_asuetos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_asuetos (id, fecha, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.fecha, NEW.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_asuetos (id, fecha, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.fecha, OLD.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_asuetos() OWNER TO postgres;

--
-- TOC entry 218 (class 1255 OID 27971)
-- Name: sp_carreras(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_carreras() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_carreras (id, id_instituto, descripcion, activo, plan, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.id_instituto, NEW.descripcion, NEW.activo, NEW.plan, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_carreras (id, id_instituto, descripcion, activo, plan, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.id_instituto, OLD.descripcion, OLD.activo, OLD.plan, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_carreras() OWNER TO postgres;

--
-- TOC entry 219 (class 1255 OID 27972)
-- Name: sp_estados_alumnos(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_estados_alumnos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_estados_alumnos (id, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_estados_alumnos (id, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_estados_alumnos() OWNER TO postgres;

--
-- TOC entry 220 (class 1255 OID 27973)
-- Name: sp_institutos(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_institutos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_institutos (id, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_institutos (id, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_institutos() OWNER TO postgres;

--
-- TOC entry 221 (class 1255 OID 27974)
-- Name: sp_localidades(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_localidades() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_localidades (id, descripcion, cp, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.descripcion, NEW.cp, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_localidades (id, descripcion, cp, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.descripcion, OLD.cp, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_localidades() OWNER TO postgres;

--
-- TOC entry 222 (class 1255 OID 27975)
-- Name: sp_materias(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_materias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_materias (id, id_carrera, id_profesor, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.id_carrera, NEW.id_profesor, NEW.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_materias (id, id_carrera, id_profesor, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.id_carrera, OLD.id_profesor, OLD.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_materias() OWNER TO postgres;

--
-- TOC entry 223 (class 1255 OID 27976)
-- Name: sp_materias_horarios(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_materias_horarios() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_materias_horarios (id, id_materia, dia_semana, hora_desde, hora_hasta, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.id_materia, NEW.dia_semana, NEW.hora_desde, NEW.hora_hasta, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_materias_horarios (id, id_materia, dia_semana, hora_desde, hora_hasta, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.id_materia, OLD.dia_semana, OLD.hora_desde, OLD.hora_hasta, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_materias_horarios() OWNER TO postgres;

--
-- TOC entry 224 (class 1255 OID 27977)
-- Name: sp_parametros(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_parametros() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_parametros (id, dias_vencimiento, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.dias_vencimiento, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_parametros (id, dias_vencimiento, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.dias_vencimiento, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_parametros() OWNER TO postgres;

--
-- TOC entry 225 (class 1255 OID 27978)
-- Name: sp_profesores(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_profesores() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_profesores (id, id_tipo_documento, numero_documento, descripcion, mail, telefono, id_localidad, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.id_tipo_documento, NEW.numero_documento, NEW.descripcion, NEW.mail, NEW.telefono, NEW.id_localidad, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_profesores (id, id_tipo_documento, numero_documento, descripcion, mail, telefono, id_localidad, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.id_tipo_documento, OLD.numero_documento, OLD.descripcion, OLD.mail, OLD.telefono, OLD.id_localidad, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_profesores() OWNER TO postgres;

--
-- TOC entry 226 (class 1255 OID 27979)
-- Name: sp_tipos_documento(); Type: FUNCTION; Schema: public_auditoria; Owner: postgres
--

CREATE FUNCTION public_auditoria.sp_tipos_documento() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				DECLARE
					schema_temp varchar;
					rtabla_usr RECORD;
					rusuario RECORD;
					vusuario VARCHAR(60);
					voperacion varchar;
					vid_solicitud integer;
					vestampilla timestamp;
				BEGIN
					vestampilla := current_timestamp;
					SELECT INTO schema_temp public.recuperar_schema_temp();
					SELECT INTO rtabla_usr * FROM pg_tables WHERE tablename = 'tt_usuario' AND schemaname = schema_temp;
					IF FOUND THEN
						SELECT INTO rusuario usuario, id_solicitud FROM tt_usuario;
						IF FOUND THEN
							vusuario := rusuario.usuario;
							vid_solicitud := rusuario.id_solicitud;
						ELSE
							vusuario := user;
							vid_solicitud := 0;
						END IF;
					ELSE
						vusuario := user;
					END IF;
					IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
						IF (TG_OP = 'INSERT') THEN
							voperacion := 'I';  
						ELSE
							voperacion := 'U';
						END IF;
				INSERT INTO public_auditoria.logs_tipos_documento (id, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (NEW.id, NEW.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					ELSIF TG_OP = 'DELETE' THEN
						voperacion := 'D';
						INSERT INTO public_auditoria.logs_tipos_documento (id, descripcion, auditoria_usuario, auditoria_fecha, auditoria_operacion, auditoria_id_solicitud) VALUES (OLD.id, OLD.descripcion, vusuario, vestampilla, voperacion, vid_solicitud);
					END IF;
					RETURN NULL;
				END;
			$$;


ALTER FUNCTION public_auditoria.sp_tipos_documento() OWNER TO postgres;

SET default_tablespace = '';

--
-- TOC entry 178 (class 1259 OID 19019)
-- Name: alumnos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.alumnos (
    id integer NOT NULL,
    id_tipo_documento integer NOT NULL,
    numero_documento character varying(80) NOT NULL,
    descripcion character varying(80) NOT NULL,
    direccion character varying(80) NOT NULL,
    telefono character varying(90),
    mail character varying(80),
    fecha_nacimiento date NOT NULL,
    legajo character varying(15) NOT NULL,
    id_localidad integer NOT NULL
);


ALTER TABLE public.alumnos OWNER TO postgres;

--
-- TOC entry 177 (class 1259 OID 19017)
-- Name: alumnos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.alumnos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alumnos_id_seq OWNER TO postgres;

--
-- TOC entry 2093 (class 0 OID 0)
-- Dependencies: 177
-- Name: alumnos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.alumnos_id_seq OWNED BY public.alumnos.id;


--
-- TOC entry 182 (class 1259 OID 19059)
-- Name: asuetos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.asuetos (
    id integer NOT NULL,
    fecha date NOT NULL,
    descripcion character varying(100) NOT NULL
);


ALTER TABLE public.asuetos OWNER TO postgres;

--
-- TOC entry 181 (class 1259 OID 19057)
-- Name: asuetos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.asuetos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.asuetos_id_seq OWNER TO postgres;

--
-- TOC entry 2094 (class 0 OID 0)
-- Dependencies: 181
-- Name: asuetos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.asuetos_id_seq OWNED BY public.asuetos.id;


--
-- TOC entry 163 (class 1259 OID 18921)
-- Name: carreras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.carreras (
    id integer NOT NULL,
    id_instituto integer,
    descripcion character varying(100) NOT NULL,
    activo boolean DEFAULT false,
    plan character varying(50)
);


ALTER TABLE public.carreras OWNER TO postgres;

--
-- TOC entry 164 (class 1259 OID 18925)
-- Name: carreras_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.carreras_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.carreras_id_seq OWNER TO postgres;

--
-- TOC entry 2095 (class 0 OID 0)
-- Dependencies: 164
-- Name: carreras_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.carreras_id_seq OWNED BY public.carreras.id;


--
-- TOC entry 176 (class 1259 OID 19009)
-- Name: estados_alumnos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estados_alumnos (
    id integer NOT NULL,
    descripcion character varying(100) NOT NULL
);


ALTER TABLE public.estados_alumnos OWNER TO postgres;

--
-- TOC entry 175 (class 1259 OID 19007)
-- Name: estados_alumnos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estados_alumnos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.estados_alumnos_id_seq OWNER TO postgres;

--
-- TOC entry 2096 (class 0 OID 0)
-- Dependencies: 175
-- Name: estados_alumnos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estados_alumnos_id_seq OWNED BY public.estados_alumnos.id;


--
-- TOC entry 165 (class 1259 OID 18927)
-- Name: institutos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.institutos (
    id integer NOT NULL,
    descripcion character varying(100) NOT NULL
);


ALTER TABLE public.institutos OWNER TO postgres;

--
-- TOC entry 166 (class 1259 OID 18930)
-- Name: institutos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.institutos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.institutos_id_seq OWNER TO postgres;

--
-- TOC entry 2097 (class 0 OID 0)
-- Dependencies: 166
-- Name: institutos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.institutos_id_seq OWNED BY public.institutos.id;


--
-- TOC entry 180 (class 1259 OID 19036)
-- Name: localidades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.localidades (
    id integer NOT NULL,
    descripcion character varying(100) NOT NULL,
    cp character varying(20) NOT NULL
);


ALTER TABLE public.localidades OWNER TO postgres;

--
-- TOC entry 179 (class 1259 OID 19034)
-- Name: localidades_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.localidades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.localidades_id_seq OWNER TO postgres;

--
-- TOC entry 2098 (class 0 OID 0)
-- Dependencies: 179
-- Name: localidades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.localidades_id_seq OWNED BY public.localidades.id;


--
-- TOC entry 167 (class 1259 OID 18932)
-- Name: materias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.materias (
    id integer NOT NULL,
    id_carrera integer NOT NULL,
    id_profesor integer NOT NULL,
    descripcion character varying(80) NOT NULL,
    ano integer
);


ALTER TABLE public.materias OWNER TO postgres;

--
-- TOC entry 168 (class 1259 OID 18935)
-- Name: materias_horarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.materias_horarios (
    id integer NOT NULL,
    id_materia integer NOT NULL,
    dia_semana character varying(9) NOT NULL,
    hora_desde time without time zone NOT NULL,
    hora_hasta time without time zone NOT NULL
);


ALTER TABLE public.materias_horarios OWNER TO postgres;

--
-- TOC entry 169 (class 1259 OID 18938)
-- Name: materias_horarios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.materias_horarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.materias_horarios_id_seq OWNER TO postgres;

--
-- TOC entry 2099 (class 0 OID 0)
-- Dependencies: 169
-- Name: materias_horarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.materias_horarios_id_seq OWNED BY public.materias_horarios.id;


--
-- TOC entry 170 (class 1259 OID 18940)
-- Name: materias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.materias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.materias_id_seq OWNER TO postgres;

--
-- TOC entry 2100 (class 0 OID 0)
-- Dependencies: 170
-- Name: materias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.materias_id_seq OWNED BY public.materias.id;


--
-- TOC entry 184 (class 1259 OID 27341)
-- Name: parametros; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametros (
    id integer NOT NULL,
    dias_vencimiento integer NOT NULL
);


ALTER TABLE public.parametros OWNER TO postgres;

--
-- TOC entry 185 (class 1259 OID 27344)
-- Name: parametros_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parametros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parametros_id_seq OWNER TO postgres;

--
-- TOC entry 2101 (class 0 OID 0)
-- Dependencies: 185
-- Name: parametros_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parametros_id_seq OWNED BY public.parametros.id;


--
-- TOC entry 171 (class 1259 OID 18942)
-- Name: profesores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profesores (
    id integer NOT NULL,
    id_tipo_documento integer NOT NULL,
    numero_documento character varying(80) NOT NULL,
    descripcion character varying(80) NOT NULL,
    mail character varying(80) NOT NULL,
    telefono character varying(80),
    id_localidad integer NOT NULL
);


ALTER TABLE public.profesores OWNER TO postgres;

--
-- TOC entry 172 (class 1259 OID 18945)
-- Name: profesores_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.profesores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.profesores_id_seq OWNER TO postgres;

--
-- TOC entry 2102 (class 0 OID 0)
-- Dependencies: 172
-- Name: profesores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.profesores_id_seq OWNED BY public.profesores.id;


--
-- TOC entry 173 (class 1259 OID 18947)
-- Name: tipos_documento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_documento (
    id integer NOT NULL,
    descripcion character varying(100) NOT NULL
);


ALTER TABLE public.tipos_documento OWNER TO postgres;

--
-- TOC entry 174 (class 1259 OID 18950)
-- Name: tipos_documento_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_documento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_documento_id_seq OWNER TO postgres;

--
-- TOC entry 2103 (class 0 OID 0)
-- Dependencies: 174
-- Name: tipos_documento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_documento_id_seq OWNED BY public.tipos_documento.id;


--
-- TOC entry 186 (class 1259 OID 27936)
-- Name: logs_alumnos; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_alumnos (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    id_tipo_documento integer,
    numero_documento character varying(80),
    descripcion character varying(80),
    direccion character varying(80),
    telefono character varying(90),
    mail character varying(80),
    fecha_nacimiento date,
    legajo character varying(15),
    id_localidad integer
);


ALTER TABLE public_auditoria.logs_alumnos OWNER TO postgres;

--
-- TOC entry 187 (class 1259 OID 27939)
-- Name: logs_asuetos; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_asuetos (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    fecha date,
    descripcion character varying(100)
);


ALTER TABLE public_auditoria.logs_asuetos OWNER TO postgres;

--
-- TOC entry 188 (class 1259 OID 27942)
-- Name: logs_carreras; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_carreras (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    id_instituto integer,
    descripcion character varying(100),
    activo boolean,
    plan character varying(50)
);


ALTER TABLE public_auditoria.logs_carreras OWNER TO postgres;

--
-- TOC entry 189 (class 1259 OID 27945)
-- Name: logs_estados_alumnos; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_estados_alumnos (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    descripcion character varying(100)
);


ALTER TABLE public_auditoria.logs_estados_alumnos OWNER TO postgres;

--
-- TOC entry 190 (class 1259 OID 27948)
-- Name: logs_institutos; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_institutos (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    descripcion character varying(100)
);


ALTER TABLE public_auditoria.logs_institutos OWNER TO postgres;

--
-- TOC entry 191 (class 1259 OID 27951)
-- Name: logs_localidades; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_localidades (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    descripcion character varying(100),
    cp character varying(20)
);


ALTER TABLE public_auditoria.logs_localidades OWNER TO postgres;

--
-- TOC entry 192 (class 1259 OID 27954)
-- Name: logs_materias; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_materias (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    id_carrera integer,
    id_profesor integer,
    descripcion character varying(80)
);


ALTER TABLE public_auditoria.logs_materias OWNER TO postgres;

--
-- TOC entry 193 (class 1259 OID 27957)
-- Name: logs_materias_horarios; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_materias_horarios (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    id_materia integer,
    dia_semana character varying(9),
    hora_desde time without time zone,
    hora_hasta time without time zone
);


ALTER TABLE public_auditoria.logs_materias_horarios OWNER TO postgres;

--
-- TOC entry 194 (class 1259 OID 27960)
-- Name: logs_parametros; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_parametros (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    dias_vencimiento integer
);


ALTER TABLE public_auditoria.logs_parametros OWNER TO postgres;

--
-- TOC entry 195 (class 1259 OID 27963)
-- Name: logs_profesores; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_profesores (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    id_tipo_documento integer,
    numero_documento character varying(80),
    descripcion character varying(80),
    mail character varying(80),
    telefono character varying(80),
    id_localidad integer
);


ALTER TABLE public_auditoria.logs_profesores OWNER TO postgres;

--
-- TOC entry 196 (class 1259 OID 27966)
-- Name: logs_tipos_documento; Type: TABLE; Schema: public_auditoria; Owner: postgres
--

CREATE TABLE public_auditoria.logs_tipos_documento (
    auditoria_usuario character varying(60),
    auditoria_fecha timestamp without time zone,
    auditoria_operacion character(1),
    auditoria_id_solicitud integer,
    id integer,
    descripcion character varying(100)
);


ALTER TABLE public_auditoria.logs_tipos_documento OWNER TO postgres;

--
-- TOC entry 1883 (class 2604 OID 19022)
-- Name: alumnos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumnos ALTER COLUMN id SET DEFAULT nextval('public.alumnos_id_seq'::regclass);


--
-- TOC entry 1885 (class 2604 OID 19062)
-- Name: asuetos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asuetos ALTER COLUMN id SET DEFAULT nextval('public.asuetos_id_seq'::regclass);


--
-- TOC entry 1876 (class 2604 OID 18952)
-- Name: carreras id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carreras ALTER COLUMN id SET DEFAULT nextval('public.carreras_id_seq'::regclass);


--
-- TOC entry 1882 (class 2604 OID 19012)
-- Name: estados_alumnos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estados_alumnos ALTER COLUMN id SET DEFAULT nextval('public.estados_alumnos_id_seq'::regclass);


--
-- TOC entry 1877 (class 2604 OID 18953)
-- Name: institutos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institutos ALTER COLUMN id SET DEFAULT nextval('public.institutos_id_seq'::regclass);


--
-- TOC entry 1884 (class 2604 OID 19039)
-- Name: localidades id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.localidades ALTER COLUMN id SET DEFAULT nextval('public.localidades_id_seq'::regclass);


--
-- TOC entry 1878 (class 2604 OID 18954)
-- Name: materias id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias ALTER COLUMN id SET DEFAULT nextval('public.materias_id_seq'::regclass);


--
-- TOC entry 1879 (class 2604 OID 18955)
-- Name: materias_horarios id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias_horarios ALTER COLUMN id SET DEFAULT nextval('public.materias_horarios_id_seq'::regclass);


--
-- TOC entry 1886 (class 2604 OID 27419)
-- Name: parametros id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros ALTER COLUMN id SET DEFAULT nextval('public.parametros_id_seq'::regclass);


--
-- TOC entry 1880 (class 2604 OID 18956)
-- Name: profesores id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profesores ALTER COLUMN id SET DEFAULT nextval('public.profesores_id_seq'::regclass);


--
-- TOC entry 1881 (class 2604 OID 18957)
-- Name: tipos_documento id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_documento ALTER COLUMN id SET DEFAULT nextval('public.tipos_documento_id_seq'::regclass);


--
-- TOC entry 2068 (class 0 OID 19019)
-- Dependencies: 178
-- Data for Name: alumnos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.alumnos VALUES (3, 1, '21508110', 'ZALACAIN VERONICA', 'LAS HERAS 1333', '0232315546258', 'vxzalacain@gmail.com', '1970-05-12', '6421', 2);
INSERT INTO public.alumnos VALUES (2, 1, '22044187', 'SOLARI SILVIO', 'LAS HERAS 1333', '0232315542000', 'solariunlu@gmail.com', '1971-04-13', '3264', 1);


--
-- TOC entry 2072 (class 0 OID 19059)
-- Dependencies: 182
-- Data for Name: asuetos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.asuetos VALUES (1, '2022-08-17', 'MUERTE DEL GENERAL SAN MARTIN');


--
-- TOC entry 2053 (class 0 OID 18921)
-- Dependencies: 163
-- Data for Name: carreras; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.carreras VALUES (19, 1, 'MUSEOLOGIA', true, 'VIGENTE');
INSERT INTO public.carreras VALUES (18, 1, 'TECNICATURA SUP. EN ANALISIS DE SISTEMAS', true, 'VIGENTE');
INSERT INTO public.carreras VALUES (15, 1, 'TECNICATURA SUP. EN ANALISIS, DESARROLLO Y PROGRAM. DE APLICACIONES', true, 'VIGENTE');
INSERT INTO public.carreras VALUES (12, 1, 'TECNICATURA SUP. EN GUIA DE TURISMO', true, 'VIGENTE');
INSERT INTO public.carreras VALUES (14, 1, 'TECNICATURA SUP. EN TURISMO', true, 'VIGENTE');


--
-- TOC entry 2066 (class 0 OID 19009)
-- Dependencies: 176
-- Data for Name: estados_alumnos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.estados_alumnos VALUES (1, 'REGULAR');
INSERT INTO public.estados_alumnos VALUES (3, 'PROMOCIONADO');
INSERT INTO public.estados_alumnos VALUES (2, 'LIBRE');


--
-- TOC entry 2055 (class 0 OID 18927)
-- Dependencies: 165
-- Data for Name: institutos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.institutos VALUES (1, 'INSTITUTO SUPERIOR DE FORMACION TECNICA ISFYT Nº 189');


--
-- TOC entry 2070 (class 0 OID 19036)
-- Dependencies: 180
-- Data for Name: localidades; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.localidades VALUES (1, 'LUJAN', '6700');
INSERT INTO public.localidades VALUES (2, 'GENERAL RODRIGUEZ', '1347');
INSERT INTO public.localidades VALUES (34, 'CAÑUELAS', '1225');


--
-- TOC entry 2057 (class 0 OID 18932)
-- Dependencies: 167
-- Data for Name: materias; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.materias VALUES (24, 14, 45, 'TEGNOLOGIA DE LA INFORMACION Y COMUNICACION APLICADA', 1);
INSERT INTO public.materias VALUES (25, 18, 19, 'A. E. DE DATOS I', 1);
INSERT INTO public.materias VALUES (27, 14, 47, 'INTERP. DEL ESPACIO TURISTICO LOCAL', 1);
INSERT INTO public.materias VALUES (28, 18, 10, 'INGLES I', 1);
INSERT INTO public.materias VALUES (29, 14, 50, 'PRACTICA PROFECIONAL', 1);
INSERT INTO public.materias VALUES (30, 14, 47, 'INTERPRETACION DEL PATRIMONIO ARGENTINO', 1);
INSERT INTO public.materias VALUES (31, 18, 29, 'ANÁLISIS MATEMÁTICO', 1);
INSERT INTO public.materias VALUES (32, 14, 40, 'INTERPRETACION DEL ESPACIO AMBIENTAL', 1);
INSERT INTO public.materias VALUES (26, 12, 10, 'INGLES I', 1);
INSERT INTO public.materias VALUES (33, 12, 31, 'PRACT PROF', 1);
INSERT INTO public.materias VALUES (34, 14, 50, 'INTRODUCCION AL TURISMO', 1);
INSERT INTO public.materias VALUES (35, 18, 21, 'ARQ. DEL. COMPUT', 1);
INSERT INTO public.materias VALUES (36, 12, 50, 'INT. AL TURISMO', 1);
INSERT INTO public.materias VALUES (37, 18, 41, 'SIST Y ORG', 1);
INSERT INTO public.materias VALUES (38, 14, 47, 'METODOLOGIA DE LA INVESTIGACION', 1);
INSERT INTO public.materias VALUES (39, 14, 10, 'INGLES I', 1);
INSERT INTO public.materias VALUES (40, 18, 39, 'C. T. Y SOC', 1);
INSERT INTO public.materias VALUES (113, 15, 9, 'SIST. OPERATIVOS', 2);
INSERT INTO public.materias VALUES (42, 18, 2, 'PRACT. PROF. I', 1);
INSERT INTO public.materias VALUES (43, 18, 29, 'ÁLGEBRA', 1);
INSERT INTO public.materias VALUES (114, 15, 21, 'EDI II', 2);
INSERT INTO public.materias VALUES (45, 12, 49, 'PSICOL. DE LOS SUJETOS', 1);
INSERT INTO public.materias VALUES (115, 15, 44, 'EDI III', 3);
INSERT INTO public.materias VALUES (116, 15, 46, 'ECO.EMPR', 3);
INSERT INTO public.materias VALUES (117, 15, 2, 'INV.OPERATIVA', 3);
INSERT INTO public.materias VALUES (118, 19, 26, 'MET. DE LA INV. MUS', 1);
INSERT INTO public.materias VALUES (119, 15, 2, 'PRACT.PROF.', 3);
INSERT INTO public.materias VALUES (120, 15, 2, 'G. BASE DE DATOS', 3);
INSERT INTO public.materias VALUES (121, 15, 21, 'TELEINFORMATICA', 3);
INSERT INTO public.materias VALUES (122, 19, 26, 'MUSEOLOGIA I', 1);
INSERT INTO public.materias VALUES (123, 15, 2, 'DISEÑO E IMP.S', 3);
INSERT INTO public.materias VALUES (124, 19, 14, 'HISTORIA DE LAS CIVILIZACIONES', 1);
INSERT INTO public.materias VALUES (125, 19, 26, 'MUSEOLOGIA II', 2);
INSERT INTO public.materias VALUES (126, 19, 36, 'IDIOMA EX. II', 2);
INSERT INTO public.materias VALUES (128, 19, 48, 'H. DE LA CULTURA AMERICANA', 2);
INSERT INTO public.materias VALUES (60, 12, 40, 'INTERP DEL AMBIENTE', 1);
INSERT INTO public.materias VALUES (127, 19, 35, 'H. DEL ARTE I', 2);
INSERT INTO public.materias VALUES (62, 12, 47, 'M. DE LA INV.', 1);
INSERT INTO public.materias VALUES (63, 12, 22, 'INT. TRANSF SOCIAL', 1);
INSERT INTO public.materias VALUES (129, 19, 38, 'CONVERSACION PREVENTIVA I', 2);
INSERT INTO public.materias VALUES (65, 12, 47, 'INTERP DEL PATRIMONIO', 1);
INSERT INTO public.materias VALUES (130, 19, 38, 'GESTION DE MUSEOS', 3);
INSERT INTO public.materias VALUES (67, 19, 36, 'IDIOMA EX. I', 1);
INSERT INTO public.materias VALUES (131, 19, 26, 'MUSEOGRAFIA III', 3);
INSERT INTO public.materias VALUES (69, 19, 39, 'INFORMATICA APLICADA', 1);
INSERT INTO public.materias VALUES (70, 12, 37, 'HIST. DE LAS CULT.', 2);
INSERT INTO public.materias VALUES (68, 12, 51, 'EDI II PORTUGUES', 2);
INSERT INTO public.materias VALUES (48, 18, 44, 'A. E. DE DATOS II', 2);
INSERT INTO public.materias VALUES (47, 18, 10, 'INGLES II', 2);
INSERT INTO public.materias VALUES (71, 14, 51, 'EDI II PORTUGUES', 2);
INSERT INTO public.materias VALUES (72, 12, 31, 'PRACT. PROF. II', 2);
INSERT INTO public.materias VALUES (53, 18, 44, 'ING SOFTWARE I', 2);
INSERT INTO public.materias VALUES (73, 14, 31, 'P. EAA. Y  OC.', 2);
INSERT INTO public.materias VALUES (54, 18, 44, 'ING SOFTWARE II', 3);
INSERT INTO public.materias VALUES (74, 14, 30, 'INGLES II', 2);
INSERT INTO public.materias VALUES (75, 12, 40, 'EET.EAA. Y OC.', 2);
INSERT INTO public.materias VALUES (76, 14, 40, 'EET.EAA. Y OC.', 2);
INSERT INTO public.materias VALUES (77, 12, 47, 'PROG C. TURIST', 2);
INSERT INTO public.materias VALUES (78, 14, 10, 'INGLES III', 3);
INSERT INTO public.materias VALUES (46, 18, 39, 'PRACT. PROF. II', 2);
INSERT INTO public.materias VALUES (79, 12, 18, 'RECREACION', 2);
INSERT INTO public.materias VALUES (80, 14, 47, 'PRACTICA PROFESIONAL II', 3);
INSERT INTO public.materias VALUES (56, 18, 19, 'PRACT. PROF. III', 3);
INSERT INTO public.materias VALUES (81, 14, 41, 'DIRECCION Y GESTION', 3);
INSERT INTO public.materias VALUES (82, 12, 10, 'INGLES II', 2);
INSERT INTO public.materias VALUES (49, 18, 9, 'BASE DE DATOS', 2);
INSERT INTO public.materias VALUES (83, 14, 53, 'EDI III', 3);
INSERT INTO public.materias VALUES (55, 18, 42, 'ASPECTOS LEGALES DE LA PROF', 3);
INSERT INTO public.materias VALUES (85, 12, 31, 'P.EAA Y OC.', 2);
INSERT INTO public.materias VALUES (86, 12, 10, 'INGLES III', 3);
INSERT INTO public.materias VALUES (87, 14, 50, 'C. DEL MEDIO AMBIENTE', 3);
INSERT INTO public.materias VALUES (51, 18, 29, 'ANÁLISIS MATEMÁTICO II', 2);
INSERT INTO public.materias VALUES (88, 12, 31, 'PRACT. PROF. III', 3);
INSERT INTO public.materias VALUES (89, 14, 32, 'COMERC. PROD. HOTELEROS Y T.', 3);
INSERT INTO public.materias VALUES (90, 14, 11, 'LEGISLACION', 3);
INSERT INTO public.materias VALUES (91, 12, 49, 'INFORMATICA', 3);
INSERT INTO public.materias VALUES (92, 12, 50, 'FOLKLORE', 3);
INSERT INTO public.materias VALUES (61, 18, 36, 'INGLES III', 3);
INSERT INTO public.materias VALUES (93, 12, 13, 'H.DEL A.ARG Y L', 3);
INSERT INTO public.materias VALUES (66, 14, 46, 'CONT. MAT. FINAN', 2);
INSERT INTO public.materias VALUES (57, 18, 21, 'REDES Y COMUNICACIONES', 3);
INSERT INTO public.materias VALUES (94, 12, 51, 'EDI III PORTUGUES', 3);
INSERT INTO public.materias VALUES (95, 12, 50, 'C DEL MED.AMB.', 3);
INSERT INTO public.materias VALUES (59, 18, 44, 'SEMINARIO DE ACTUALIZACION', 3);
INSERT INTO public.materias VALUES (96, 12, 11, 'LEGISLACION', 3);
INSERT INTO public.materias VALUES (52, 18, 9, 'SIST. OPERATIVOS', 2);
INSERT INTO public.materias VALUES (97, 15, 39, 'M. DE LA INV.', 1);
INSERT INTO public.materias VALUES (41, 14, 32, 'ORGANIZACION Y ADMINISTRACION', 2);
INSERT INTO public.materias VALUES (64, 14, 47, 'PRACTICA PROFECIONAL I', 2);
INSERT INTO public.materias VALUES (98, 15, 21, 'SIST. DE COMPUTACION', 1);
INSERT INTO public.materias VALUES (50, 18, 28, 'ESTADISTICA', 2);
INSERT INTO public.materias VALUES (99, 15, 25, 'EDI I', 1);
INSERT INTO public.materias VALUES (44, 14, 31, 'PROG DE C TURIS', 2);
INSERT INTO public.materias VALUES (100, 15, 15, 'ADM DE ORG.', 1);
INSERT INTO public.materias VALUES (101, 15, 29, 'ANAL. MATEM. I', 1);
INSERT INTO public.materias VALUES (102, 15, 10, 'INGLES I', 1);
INSERT INTO public.materias VALUES (103, 15, 25, 'PROGRAM. I', 1);
INSERT INTO public.materias VALUES (104, 15, 52, 'ALGEBRA', 1);
INSERT INTO public.materias VALUES (105, 15, 9, 'BASE DE DATOS', 2);
INSERT INTO public.materias VALUES (106, 15, 28, 'PROB. Y EST.', 2);
INSERT INTO public.materias VALUES (107, 15, 30, 'INGLES TEC.II', 2);
INSERT INTO public.materias VALUES (108, 15, 33, 'PROG. O. A OBJ', 2);
INSERT INTO public.materias VALUES (109, 15, 44, 'SEMINARIO PROG.', 2);
INSERT INTO public.materias VALUES (110, 15, 39, 'ANAL. DE SIST.', 2);
INSERT INTO public.materias VALUES (111, 18, 44, 'ALG Y EST DE DATOS III', 3);
INSERT INTO public.materias VALUES (112, 15, 29, 'ANAL. MATEM.II', 2);
INSERT INTO public.materias VALUES (132, 19, 35, 'HISTORIA DEL ARTE II', 3);


--
-- TOC entry 2058 (class 0 OID 18935)
-- Dependencies: 168
-- Data for Name: materias_horarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.materias_horarios VALUES (119, 115, 'Martes', '17:00:00', '18:00:00');
INSERT INTO public.materias_horarios VALUES (120, 115, 'Miercoles', '17:00:00', '18:00:00');
INSERT INTO public.materias_horarios VALUES (121, 117, 'Martes', '18:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (122, 119, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (18, 124, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (19, 39, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (20, 25, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (21, 26, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (22, 36, 'Viernes', '18:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (23, 97, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (26, 63, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (27, 40, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (28, 60, 'Lunes', '18:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (29, 28, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (30, 65, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (31, 31, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (32, 32, 'Viernes', '18:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (33, 102, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (34, 62, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (35, 25, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (36, 27, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (37, 98, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (38, 35, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (39, 30, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (40, 42, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (41, 37, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (42, 98, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (43, 34, 'Miercoles', '19:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (44, 33, 'Jueves', '18:00:00', '19:00:00');
INSERT INTO public.materias_horarios VALUES (45, 38, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (46, 43, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (47, 29, 'Miercoles', '18:00:00', '19:00:00');
INSERT INTO public.materias_horarios VALUES (48, 45, 'Lunes', '21:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (49, 103, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (50, 47, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (51, 45, 'Martes', '19:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (52, 24, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (53, 50, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (54, 66, 'Viernes', '18:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (55, 71, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (56, 48, 'Martes', '18:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (57, 103, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (58, 68, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (60, 46, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (61, 75, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (62, 99, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (59, 76, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (63, 70, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (64, 100, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (65, 51, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (66, 74, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (67, 82, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (68, 41, 'Lunes', '18:00:00', '19:00:00');
INSERT INTO public.materias_horarios VALUES (69, 101, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (70, 49, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (71, 85, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (72, 73, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (73, 104, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (74, 64, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (75, 72, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (76, 44, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (77, 106, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (78, 87, 'Lunes', '20:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (79, 53, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (80, 109, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (81, 89, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (82, 77, 'Viernes', '17:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (83, 81, 'Martes', '18:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (84, 46, 'Viernes', '17:00:00', '19:00:00');
INSERT INTO public.materias_horarios VALUES (85, 83, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (86, 79, 'Lunes', '19:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (87, 78, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (88, 105, 'Martes', '17:00:00', '19:00:00');
INSERT INTO public.materias_horarios VALUES (89, 90, 'Lunes', '21:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (90, 95, 'Lunes', '19:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (91, 54, 'Lunes', '17:00:00', '18:00:00');
INSERT INTO public.materias_horarios VALUES (92, 110, 'Martes', '19:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (93, 80, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (94, 54, 'Jueves', '17:00:00', '18:00:00');
INSERT INTO public.materias_horarios VALUES (95, 94, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (96, 107, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (97, 92, 'Lunes', '18:00:00', '19:00:00');
INSERT INTO public.materias_horarios VALUES (98, 93, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (99, 113, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (100, 55, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (101, 91, 'Viernes', '17:00:00', '18:00:00');
INSERT INTO public.materias_horarios VALUES (102, 56, 'Martes', '18:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (103, 108, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (104, 57, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (105, 59, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (106, 112, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (107, 56, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (108, 108, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (109, 111, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (110, 111, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (111, 86, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (112, 61, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (113, 96, 'Lunes', '20:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (114, 114, 'Viernes', '20:00:00', '21:00:00');
INSERT INTO public.materias_horarios VALUES (115, 88, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (116, 88, 'Jueves', '19:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (117, 116, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (118, 123, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (123, 119, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public.materias_horarios VALUES (124, 120, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public.materias_horarios VALUES (125, 121, 'Viernes', '18:00:00', '20:00:00');


--
-- TOC entry 2073 (class 0 OID 27341)
-- Dependencies: 184
-- Data for Name: parametros; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.parametros VALUES (1, 30);


--
-- TOC entry 2061 (class 0 OID 18942)
-- Dependencies: 171
-- Data for Name: profesores; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.profesores VALUES (2, 1, '22044187', 'SOLARI SILVIO HUGO', 'solariunlu@gmail.com', '0232315542000', 1);
INSERT INTO public.profesores VALUES (9, 1, '12566071', 'ROMERO JUAN CARLOS', 'juancarlosjromer@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (10, 1, '28179414', 'HERNANDEZ JESICA', 'hernandez.jesica@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (11, 1, '17522715', 'ANTÚNEZ FERNANDO', 'ferantu31@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (12, 1, '35726393', 'SCARAMELLA EMILIANA', 'emilianascaramella@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (13, 1, '31259494', 'ASENZO MA VERNABÉ', 'bernabeasenzo@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (14, 1, '13620552', 'KRAUTH ENRIQUE', 'quiquekrauth@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (15, 1, '28473736', 'SCHOENFELD ALEJANDRO', 'alejandro.schoenfeld@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (16, 1, '14097206', 'LAVORATO MARIA CECILIA', 'cecilialavorato@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (17, 1, '22860328', 'AZZINNARI PABLO A', 'pablo_adrian1972@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (18, 1, '22356132', 'LOPEZ CALCAGNO YANIL', 'yanil_lopezcalcagno@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (19, 1, '13681943', 'BERGAGNA MIGUEL', 'mab57isft@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (20, 1, '32850297', 'SCHOENFELD PAOLA', 'paolaschoenfeld@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (21, 1, '24500298', 'LUQUE FELIX A', 'felix_luque@yahoo.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (22, 1, '31777599', 'BIBOW SOLANA', 'solanabibow@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (23, 1, '16618699', 'CAERO JOSE LUIS', 'josecaero@yahoo.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (24, 1, '14789150', 'MACCARRONE ADRIANA', 'acmaccarrone@yahoo.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (25, 1, '25778327', 'MARENGO HERNAN', 'marengohernan@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (26, 1, '21508263', 'CANO MAURICIO', 'mauriciojcano@yahoo.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (27, 1, '4791112', 'TARTAGLIA MA. TERESA', 'mariatsilvano@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (28, 1, '25638872', 'MARTINEZ CARLA', 'carla.r.martinez@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (29, 1, '16316263', 'TORRES ANA', 'anato963@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (30, 1, '25153801', 'CARDOSO FATIMA', 'fatibeatrizcardozo@yahoo.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (31, 1, '24142187', 'MARTINEZ SEBASTIAN', 'sebastianmartinez189turismo@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (32, 1, '21435616', 'VAZQUEZ CLAUDIA', 'cvazquezbanchero@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (33, 1, '24142552', 'CHERCOLES JAVIER', 'javiero@chercoles.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (35, 1, '34153080', 'VERDEJO MAGDALENA', 'magdalenaverdejo@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (36, 1, '27464737', 'CHIMIELEWSKI MARA', 'mara_natalia@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (37, 1, '21548425', 'VERGAGNI SILVIA F.', 'fernandav@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (38, 1, '14822435', 'MELLONI VIVIANA', 'a@a.com', NULL, 1);
INSERT INTO public.profesores VALUES (39, 1, '23087283', 'D´ALESSANDRO ANA C', 'acdalessandro@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (40, 1, '7656708', 'MILANIESI OSCAR', 'oscarmilanesi189turismo@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (41, 1, '17063499', 'DEL BUONO MA ISABEL', 'mdelbuono17@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (42, 1, '17119257', 'PERAZZO PATRICIA', 'patriciapuncel@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (43, 1, '24142364', 'DIAZ MARA LORENA', 'fausta@live.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (44, 1, '22154641', 'PERELLO MARIO', 'mperello04@yahoo.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (45, 1, '25136186', 'DOMINGUEZ MARINA', 'domingm2@yahoo.com.at', NULL, 1);
INSERT INTO public.profesores VALUES (46, 1, '105300005', 'PEREZ MA. DEL CARMEN', 'mariadelcarmenperez_52@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (47, 1, '24142093', 'FERRARI LEONARDO', 'leonardo.cesar.ferrari@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (48, 1, '30401629', 'POSTOLOW NADIA', 'nadiapostolow@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (49, 1, '23775366', 'GAITAN MA FERNANDA', 'fernandagaitan2002@yahoo.com.ar', NULL, 1);
INSERT INTO public.profesores VALUES (50, 1, '24500003', 'RAMIREZ ROMINA', 'romina.ramirez.turismo@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (51, 1, '32640035', 'GHIONI MARIA CARLA', 'contodaslasletras@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (52, 1, '27735240', 'REY ESTEBAN', 'estebanrey2105@gmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (53, 1, '18457000', 'GIULIANO ALBERTO', 'giulianopro10@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (54, 1, '35025063', 'RIZZO ROCIO', 'rociobelenrizzo@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (55, 1, '16029902', 'HEIRAS OSCAR', 'oscarheiras@hotmail.com', NULL, 1);
INSERT INTO public.profesores VALUES (56, 1, '20967041', 'ROBLEDO MARCELO', 'rodomarce@gmail.com', NULL, 1);


--
-- TOC entry 2063 (class 0 OID 18947)
-- Dependencies: 173
-- Data for Name: tipos_documento; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.tipos_documento VALUES (1, 'DOCUMENTO UNICO DE IDENTIDAD');
INSERT INTO public.tipos_documento VALUES (2, 'LIBRETA CIVICA');
INSERT INTO public.tipos_documento VALUES (3, 'LIBRETA DE ENROLAMIENTO');
INSERT INTO public.tipos_documento VALUES (5, 'PASAPORTE');


--
-- TOC entry 2075 (class 0 OID 27936)
-- Dependencies: 186
-- Data for Name: logs_alumnos; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--

INSERT INTO public_auditoria.logs_alumnos VALUES ('postgres', '2022-09-30 19:14:35.092', 'U', NULL, 2, 1, '22044187', 'SOLARI SILVIO', 'LAS HERAS 1333', '0232315542000', 'solariunlu@gmail.com', '1971-04-13', '3264', 1);


--
-- TOC entry 2076 (class 0 OID 27939)
-- Dependencies: 187
-- Data for Name: logs_asuetos; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--



--
-- TOC entry 2077 (class 0 OID 27942)
-- Dependencies: 188
-- Data for Name: logs_carreras; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--

INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:20:43.314', 'D', NULL, 13, 1, 'ANALISTA DE SISTEMAS', false, 'ANTERIOR');
INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:41:50.869', 'U', NULL, 18, 1, 'TECNICATURA SUP. EN ANALISIS DE SISTEMAS', true, 'VIGENTE');
INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:42:30.484', 'U', NULL, 14, 1, 'TECNICATURA SUP. EN GUIA DE TURISMO', true, 'VIGENTE');
INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:43:02.201', 'U', NULL, 12, 1, 'TECNICATURA SUP. EN TURISMO', true, 'VIGENTE');
INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:43:47.56', 'U', NULL, 15, 1, 'TECNICATURA SUP. EN ANALISIS, DESARROLLO Y PROGRAM. DE APLICACIONES', true, 'VIGENTE');
INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:56:35.407', 'U', NULL, 14, 1, 'TECNICATURA SUP. EN TURISMO----', true, 'VIGENTE');
INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:56:42.361', 'U', NULL, 12, 1, 'TECNICATURA SUP. EN GUIA DE TURISMO', true, 'VIGENTE');
INSERT INTO public_auditoria.logs_carreras VALUES ('postgres', '2022-10-03 20:56:48.534', 'U', NULL, 14, 1, 'TECNICATURA SUP. EN TURISMO', true, 'VIGENTE');


--
-- TOC entry 2078 (class 0 OID 27945)
-- Dependencies: 189
-- Data for Name: logs_estados_alumnos; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--



--
-- TOC entry 2079 (class 0 OID 27948)
-- Dependencies: 190
-- Data for Name: logs_institutos; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--

INSERT INTO public_auditoria.logs_institutos VALUES ('postgres', '2022-10-03 20:41:16.274', 'U', NULL, 1, 'ISFYT 189');
INSERT INTO public_auditoria.logs_institutos VALUES ('postgres', '2022-10-03 20:52:51.471', 'U', NULL, 1, 'ISFYT Nº 189');
INSERT INTO public_auditoria.logs_institutos VALUES ('postgres', '2022-10-03 20:54:59.63', 'U', NULL, 1, 'INSTITUTO SUPERIOR DE FORMACIÓN TÉCNICA ISFYT Nº 189');
INSERT INTO public_auditoria.logs_institutos VALUES ('postgres', '2022-10-03 20:55:15.424', 'U', NULL, 1, 'INSTITUTO SUPERIOR DE FORMACION TECNICA ISFYT Nº 189');


--
-- TOC entry 2080 (class 0 OID 27951)
-- Dependencies: 191
-- Data for Name: logs_localidades; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--



--
-- TOC entry 2081 (class 0 OID 27954)
-- Dependencies: 192
-- Data for Name: logs_materias; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--

INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:20:12.715', 'D', NULL, 22, 15, 2, 'DISEÑO E IMPLEMENTACION DE SISTEMAS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:20:14.621', 'D', NULL, 5, 15, 2, 'GESTION DE BASES DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:20:16.564', 'D', NULL, 21, 14, 3, 'INGLES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:20:18.463', 'D', NULL, 4, 15, 2, 'INVESTIGACION OPERATIVA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:20:20.142', 'D', NULL, 20, 15, 2, 'PRACTICAS PROFESIONALES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:45:34.806', 'I', NULL, 23, 14, 40, 'INTERP DEL AMBIENTE');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:48:56.499', 'I', NULL, 24, 14, 45, 'TEGNOLOGIA DE LA INFORMACION Y COMUNICACION APLICADA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:49:18.683', 'I', NULL, 25, 18, 19, 'A. E. DE DATOS I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:49:26.808', 'I', NULL, 26, 12, 10, 'INGLES 1');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:49:27.858', 'I', NULL, 27, 14, 47, 'INTERP. DEL ESPACIO TURISTICO LOCAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:49:43.133', 'I', NULL, 28, 18, 10, 'INGLES I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:49:57.001', 'I', NULL, 29, 14, 50, 'PRACTICA PROFECIONAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:50:19.945', 'I', NULL, 30, 14, 47, 'INTERPRETACION DEL PATRIMONIO ARGENTINO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:50:40.718', 'I', NULL, 31, 18, 29, 'ANÁLISIS MATEMÁTICO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:50:43.797', 'I', NULL, 32, 14, 40, 'INTERPRETACION DEL ESPACIO AMBIENTAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:50:56.183', 'U', NULL, 26, 12, 10, 'INGLES I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:51:28.603', 'I', NULL, 33, 12, 31, 'PRACT PROF');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:51:38.937', 'I', NULL, 34, 14, 50, 'INTRODUCCION AL TURISMO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:51:39.68', 'I', NULL, 35, 18, 21, 'ARQ. DEL. COMPUT');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:51:45.519', 'I', NULL, 36, 12, 50, 'INT. AL TURISMO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:51:55.044', 'I', NULL, 37, 18, 41, 'SIST Y ORG');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:52:04.874', 'I', NULL, 38, 14, 47, 'METODOLOGIA DE LA INVESTIGACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:52:16.668', 'I', NULL, 39, 14, 10, 'INGLES I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:52:16.939', 'I', NULL, 40, 18, 39, 'C. T. Y SOC');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:52:42.682', 'I', NULL, 41, 14, 32, 'ORGANIZACION Y ADMINISTRACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:52:46.844', 'I', NULL, 42, 18, 2, 'PRACT. PROF. I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:53:01.556', 'I', NULL, 43, 18, 29, 'ÁLGEBRA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:53:08.628', 'I', NULL, 44, 14, 31, 'PROG DE C TURIS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:53:14.261', 'I', NULL, 45, 12, 49, 'PSICOL. DE LOS SUJETOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:53:31.008', 'I', NULL, 46, 18, 39, 'PRACT. PROF. II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:53:47.272', 'I', NULL, 47, 18, 10, 'INGLES II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:56:19.971', 'I', NULL, 48, 18, 44, 'A. E. DE DATOS II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:57:15.189', 'I', NULL, 49, 18, 9, 'BASE DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:57:31.893', 'I', NULL, 50, 18, 28, 'ESTADISTICA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:58:09.444', 'I', NULL, 51, 18, 29, 'ANÁLISIS MATEMÁTICO II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:58:30.059', 'I', NULL, 52, 18, 9, 'SIST. OPERATIVOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:59:09.798', 'I', NULL, 53, 18, 44, 'ING SOFTWARE I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 20:59:40.211', 'I', NULL, 54, 18, 44, 'ING SOFTWARE II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:00:45.684', 'I', NULL, 55, 18, 42, 'ASPECTOS LEGALES DE LA PROF');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:00:59.8', 'I', NULL, 56, 18, 19, 'PRACT. PROF. III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:01:40.998', 'I', NULL, 57, 18, 21, 'REDES Y COMUNICACIONES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:02:01.121', 'I', NULL, 58, 18, 44, 'ALG. Y EST DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:02:23.61', 'I', NULL, 59, 18, 44, 'SEMINARIO DE ACTUALIZACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:02:51.014', 'I', NULL, 60, 12, 40, 'INTERP DEL AMBIENTE');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:03:08.559', 'I', NULL, 61, 18, 36, 'INGLES III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:03:24.529', 'I', NULL, 62, 12, 47, 'M. DE LA INV.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:03:53.63', 'I', NULL, 63, 12, 22, 'INT. TRANSF SOCIAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:04:23.319', 'I', NULL, 64, 14, 47, 'PRACTICA PROFECIONAL I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:04:46.363', 'I', NULL, 65, 12, 47, 'INTERP DEL PATRIMONIO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:04:48.853', 'I', NULL, 66, 14, 46, 'CONT. MAT. FINAN');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:14:48.688', 'I', NULL, 67, 19, 36, 'IDIOMA EX. I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:14:55.598', 'I', NULL, 68, 12, 51, 'EDI II PORTUGUES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:15:27.713', 'I', NULL, 69, 19, 39, 'INFORMATICA APLICADA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 23, 14, 40, 'INTERP DEL AMBIENTE');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 24, 14, 45, 'TEGNOLOGIA DE LA INFORMACION Y COMUNICACION APLICADA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 25, 18, 19, 'A. E. DE DATOS I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 27, 14, 47, 'INTERP. DEL ESPACIO TURISTICO LOCAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 28, 18, 10, 'INGLES I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 29, 14, 50, 'PRACTICA PROFECIONAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 30, 14, 47, 'INTERPRETACION DEL PATRIMONIO ARGENTINO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 31, 18, 29, 'ANÁLISIS MATEMÁTICO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 32, 14, 40, 'INTERPRETACION DEL ESPACIO AMBIENTAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 26, 12, 10, 'INGLES I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 33, 12, 31, 'PRACT PROF');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 34, 14, 50, 'INTRODUCCION AL TURISMO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 35, 18, 21, 'ARQ. DEL. COMPUT');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 36, 12, 50, 'INT. AL TURISMO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 37, 18, 41, 'SIST Y ORG');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 38, 14, 47, 'METODOLOGIA DE LA INVESTIGACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 39, 14, 10, 'INGLES I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 40, 18, 39, 'C. T. Y SOC');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 41, 14, 32, 'ORGANIZACION Y ADMINISTRACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 42, 18, 2, 'PRACT. PROF. I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 43, 18, 29, 'ÁLGEBRA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 44, 14, 31, 'PROG DE C TURIS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 45, 12, 49, 'PSICOL. DE LOS SUJETOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 46, 18, 39, 'PRACT. PROF. II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 47, 18, 10, 'INGLES II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 48, 18, 44, 'A. E. DE DATOS II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 49, 18, 9, 'BASE DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 50, 18, 28, 'ESTADISTICA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 51, 18, 29, 'ANÁLISIS MATEMÁTICO II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 52, 18, 9, 'SIST. OPERATIVOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 53, 18, 44, 'ING SOFTWARE I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 54, 18, 44, 'ING SOFTWARE II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 55, 18, 42, 'ASPECTOS LEGALES DE LA PROF');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 56, 18, 19, 'PRACT. PROF. III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 57, 18, 21, 'REDES Y COMUNICACIONES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 58, 18, 44, 'ALG. Y EST DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 59, 18, 44, 'SEMINARIO DE ACTUALIZACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 60, 12, 40, 'INTERP DEL AMBIENTE');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 61, 18, 36, 'INGLES III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 62, 12, 47, 'M. DE LA INV.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 63, 12, 22, 'INT. TRANSF SOCIAL');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 64, 14, 47, 'PRACTICA PROFECIONAL I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 65, 12, 47, 'INTERP DEL PATRIMONIO');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 66, 14, 46, 'CONT. MAT. FINAN');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 67, 19, 36, 'IDIOMA EX. I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 68, 12, 51, 'EDI II PORTUGUES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:02.174', 'U', NULL, 69, 19, 39, 'INFORMATICA APLICADA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:16:41.763', 'I', NULL, 70, 12, 37, 'HIST. DE LAS CULT.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:17:01.411', 'U', NULL, 68, 12, 51, 'EDI II PORTUGUES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:17:57.268', 'U', NULL, 48, 18, 44, 'A. E. DE DATOS II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:18:24.62', 'U', NULL, 47, 18, 10, 'INGLES II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:18:25.955', 'I', NULL, 71, 14, 51, 'EDI II PORTUGUES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:03.841', 'I', NULL, 72, 12, 31, 'PRACT. PROF. II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:05.945', 'U', NULL, 53, 18, 44, 'ING SOFTWARE I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:10.422', 'I', NULL, 73, 14, 31, 'P. EAA. Y  OC.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:18.697', 'U', NULL, 54, 18, 44, 'ING SOFTWARE II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:25.447', 'I', NULL, 74, 14, 30, 'INGLES II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:34.659', 'I', NULL, 75, 12, 40, 'EET.EAA. Y OC.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:50.504', 'I', NULL, 76, 14, 40, 'EET.EAA. Y OC.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:19:56.25', 'I', NULL, 77, 12, 47, 'PROG C. TURIST');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:12.736', 'I', NULL, 78, 14, 10, 'INGLES III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:16.962', 'U', NULL, 46, 18, 39, 'PRACT. PROF. II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:24.66', 'I', NULL, 79, 12, 18, 'RECREACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:29.256', 'I', NULL, 80, 14, 47, 'PRACTICA PROFESIONAL II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:37.457', 'U', NULL, 56, 18, 19, 'PRACT. PROF. III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:46.422', 'I', NULL, 81, 14, 41, 'DIRECCION Y GESTION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:47.657', 'I', NULL, 82, 12, 10, 'INGLES II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:20:59.95', 'U', NULL, 49, 18, 9, 'BASE DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:21:02.296', 'I', NULL, 83, 14, 53, 'EDI III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:21:23.276', 'U', NULL, 55, 18, 42, 'ASPECTOS LEGALES DE LA PROF');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:21:25.458', 'I', NULL, 85, 12, 31, 'P.EAA Y OC.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:21:53.516', 'I', NULL, 86, 12, 10, 'INGLES III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:22:08.577', 'I', NULL, 87, 14, 50, 'C. DEL MEDIO AMBIENTE');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:22:12.417', 'U', NULL, 51, 18, 29, 'ANÁLISIS MATEMÁTICO II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:22:25.536', 'I', NULL, 88, 12, 31, 'PRACT. PROF. III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:22:31.034', 'I', NULL, 89, 14, 32, 'COMERC. PROD. HOTELEROS Y T.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:22:41.868', 'U', NULL, 58, 18, 44, 'ALG. Y EST DE DATOS I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:22:48.603', 'I', NULL, 90, 14, 11, 'LEGISLACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:23:11.112', 'I', NULL, 91, 12, 49, 'INFORMATICA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:23:32.046', 'I', NULL, 92, 12, 50, 'FOLKLORE');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:23:42.1', 'U', NULL, 61, 18, 36, 'INGLES III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:23:50.498', 'I', NULL, 93, 12, 13, 'H.DEL A.ARG Y L');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:23:55.74', 'U', NULL, 66, 14, 46, 'CONT. MAT. FINAN');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:24:14.995', 'U', NULL, 57, 18, 21, 'REDES Y COMUNICACIONES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:24:21.568', 'I', NULL, 94, 12, 51, 'EDI III PORTUGUES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:24:56.32', 'I', NULL, 95, 12, 50, 'C DEL MED.AMB.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:25:15.413', 'U', NULL, 59, 18, 44, 'SEMINARIO DE ACTUALIZACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:25:20.197', 'I', NULL, 96, 12, 11, 'LEGISLACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:26:01.098', 'U', NULL, 52, 18, 9, 'SIST. OPERATIVOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:26:14.608', 'I', NULL, 97, 15, 39, 'M. DE LA INV.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:26:30.521', 'U', NULL, 41, 14, 32, 'ORGANIZACION Y ADMINISTRACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:26:53.859', 'U', NULL, 64, 14, 47, 'PRACTICA PROFECIONAL I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:26:58.658', 'I', NULL, 98, 15, 21, 'SIST. DE COMPUTACION');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:27:11.744', 'U', NULL, 50, 18, 28, 'ESTADISTICA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:27:14.752', 'I', NULL, 99, 15, 25, 'EDI I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:27:34.143', 'U', NULL, 44, 14, 31, 'PROG DE C TURIS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:28:03.703', 'I', NULL, 100, 15, 15, 'ADM DE ORG.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:28:24.125', 'I', NULL, 101, 15, 29, 'ANAL. MATEM. I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:28:43.029', 'I', NULL, 102, 15, 10, 'INGLES I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:29:09.756', 'I', NULL, 103, 15, 25, 'PROGRAM. I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:30:04.67', 'I', NULL, 104, 15, 52, 'ALGEBRA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:30:27.188', 'I', NULL, 105, 15, 9, 'BASE DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:30:58.404', 'I', NULL, 106, 15, 28, 'PROB. Y EST.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:31:20.21', 'I', NULL, 107, 15, 30, 'INGLES TEC.II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:31:51.121', 'I', NULL, 108, 15, 33, 'PROG. O. A OBJ');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:32:17.736', 'I', NULL, 109, 15, 44, 'SEMINARIO PROG.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:32:36.289', 'I', NULL, 110, 15, 39, 'ANAL. DE SIST.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:33:21.775', 'I', NULL, 111, 18, 44, 'ALG Y EST DE DATOS III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:33:25.984', 'I', NULL, 112, 15, 29, 'ANAL. MATEM.II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:34:04.863', 'I', NULL, 113, 15, 9, 'SIST. OPERATIVOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:34:21.406', 'I', NULL, 114, 15, 21, 'EDI II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:35:06.363', 'I', NULL, 115, 15, 44, 'EDI III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:35:26.114', 'I', NULL, 116, 15, 46, 'ECO.EMPR');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:35:42.617', 'I', NULL, 117, 15, 2, 'INV.OPERATIVA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:35:52.709', 'I', NULL, 118, 19, 26, 'MET. DE LA INV. MUS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:36:01.793', 'I', NULL, 119, 15, 2, 'PRACT.PROF.');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:36:20.67', 'I', NULL, 120, 15, 2, 'G. BASE DE DATOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:36:32.983', 'I', NULL, 121, 15, 21, 'TELEINFORMATICA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:36:39.459', 'I', NULL, 122, 19, 26, 'MUSEOLOGIA I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:36:54.407', 'I', NULL, 123, 15, 2, 'DISEÑO E IMP.S');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:37:03.954', 'I', NULL, 124, 19, 14, 'HISTORIA DE LAS CIVILIZACIONES');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-03 21:37:36.649', 'I', NULL, 125, 19, 26, 'MUSEOLOGIA II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:26:07.958', 'I', NULL, 126, 19, 36, 'IDIOMA EX. II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:27:31.16', 'I', NULL, 127, 19, 35, 'H. DEL ARTE I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:28:23.894', 'I', NULL, 128, 19, 48, 'H. DE LA CULTURA AMERICANA');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:28:47.319', 'U', NULL, 127, 19, 35, 'H. DEL ARTE I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:29:46.341', 'I', NULL, 129, 19, 38, 'CONVERSACION PREVENTIVA I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:30:16.428', 'I', NULL, 130, 19, 38, 'GESTION DE MUSEOS');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:30:59.012', 'I', NULL, 131, 19, 26, 'MUSEOGRAFIA III');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:31:53.613', 'I', NULL, 132, 19, 35, 'HISTORIA DEL ARTE II');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:48:06.382', 'D', NULL, 58, 18, 44, 'ALG. Y EST DE DATOS I');
INSERT INTO public_auditoria.logs_materias VALUES ('postgres', '2022-10-04 18:50:24.153', 'D', NULL, 23, 14, 40, 'INTERP DEL AMBIENTE');


--
-- TOC entry 2082 (class 0 OID 27957)
-- Dependencies: 193
-- Data for Name: logs_materias_horarios; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--

INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 19:53:21.118', 'D', NULL, 3, 4, 'Martes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 19:53:36.289', 'I', NULL, 13, 4, 'Martes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 20:14:15.76', 'U', NULL, 6, 21, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 20:14:27.291', 'U', NULL, 7, 5, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 20:14:44.599', 'U', NULL, 5, 20, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 20:14:57.458', 'I', NULL, 14, 21, 'Martes', '18:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 20:15:03.078', 'D', NULL, 14, 21, 'Martes', '18:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 21:08:46.535', 'I', NULL, 17, 20, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-09-30 21:09:32.498', 'D', NULL, 17, 20, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-03 20:19:43.722', 'D', NULL, 10, 22, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-03 20:19:49.567', 'D', NULL, 7, 5, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-03 20:19:55.668', 'D', NULL, 13, 4, 'Martes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-03 20:20:01.456', 'D', NULL, 5, 20, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-03 20:20:04.273', 'D', NULL, 4, 20, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-03 20:20:09.781', 'D', NULL, 6, 21, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:36:15.094', 'I', NULL, 18, 124, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:46:16.739', 'I', NULL, 19, 39, 'Martes', '20:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:46:27.996', 'U', NULL, 19, 39, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:46:28.551', 'I', NULL, 20, 25, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:46:37.63', 'I', NULL, 21, 26, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:47:25.872', 'I', NULL, 22, 36, 'Viernes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:47:32.396', 'I', NULL, 23, 97, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:47:53.808', 'I', NULL, 24, 23, 'Viernes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:48:14.28', 'I', NULL, 25, 97, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:48:27.404', 'I', NULL, 26, 63, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:48:47.564', 'I', NULL, 27, 40, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:48:49.671', 'D', NULL, 25, 97, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:48:57.514', 'I', NULL, 28, 60, 'Lunes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:49:05.296', 'I', NULL, 29, 28, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:49:24.54', 'I', NULL, 30, 65, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:49:39.293', 'I', NULL, 31, 31, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:49:47.574', 'I', NULL, 32, 32, 'Viernes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:49:52.975', 'I', NULL, 33, 102, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:03.657', 'I', NULL, 34, 62, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:14.008', 'I', NULL, 35, 25, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:19.879', 'D', NULL, 24, 23, 'Viernes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:42.773', 'I', NULL, 36, 27, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:43.606', 'I', NULL, 37, 98, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:44.029', 'I', NULL, 38, 35, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:59.18', 'I', NULL, 39, 30, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:50:59.775', 'I', NULL, 40, 42, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:10.853', 'I', NULL, 41, 37, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:12.876', 'I', NULL, 42, 98, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:14.109', 'I', NULL, 43, 34, 'Miercoles', '19:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:15.45', 'I', NULL, 44, 33, 'Jueves', '18:00:00', '19:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:26.503', 'I', NULL, 45, 38, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:32.86', 'I', NULL, 46, 43, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:49.25', 'I', NULL, 47, 29, 'Miercoles', '18:00:00', '19:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:51:51.557', 'I', NULL, 48, 45, 'Lunes', '21:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:02.767', 'I', NULL, 49, 103, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:05.823', 'I', NULL, 50, 47, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:11.966', 'I', NULL, 51, 45, 'Martes', '19:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:16.845', 'I', NULL, 52, 24, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:23.363', 'I', NULL, 53, 50, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:38.387', 'I', NULL, 54, 66, 'Viernes', '18:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:50.567', 'I', NULL, 55, 71, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:52.81', 'I', NULL, 56, 48, 'Martes', '18:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:57.038', 'I', NULL, 57, 103, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:52:59.326', 'I', NULL, 58, 68, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:06.47', 'I', NULL, 59, 76, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:12.515', 'I', NULL, 60, 46, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:16.558', 'I', NULL, 61, 75, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:22.008', 'I', NULL, 62, 99, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:31.616', 'U', NULL, 59, 76, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:37.854', 'I', NULL, 63, 70, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:44.404', 'I', NULL, 64, 100, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:49.358', 'I', NULL, 65, 51, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:52.406', 'I', NULL, 66, 74, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:53:58.128', 'I', NULL, 67, 82, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:05.341', 'I', NULL, 68, 41, 'Lunes', '18:00:00', '19:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:09.397', 'I', NULL, 69, 101, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:13.379', 'I', NULL, 70, 49, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:14', 'I', NULL, 71, 85, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:21.034', 'I', NULL, 72, 73, 'Martes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:29.635', 'I', NULL, 73, 104, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:34.605', 'I', NULL, 74, 64, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:37.919', 'I', NULL, 75, 72, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:54:51.692', 'I', NULL, 76, 44, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:55:00.209', 'I', NULL, 77, 106, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:55:42.443', 'I', NULL, 78, 87, 'Lunes', '20:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:55:44.05', 'I', NULL, 79, 53, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:55:48.464', 'I', NULL, 80, 109, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:55:55.054', 'I', NULL, 81, 89, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:02.796', 'I', NULL, 82, 77, 'Viernes', '17:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:07.61', 'I', NULL, 83, 81, 'Martes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:16.154', 'I', NULL, 84, 46, 'Viernes', '17:00:00', '19:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:21.238', 'I', NULL, 85, 83, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:26.784', 'I', NULL, 86, 79, 'Lunes', '19:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:31.969', 'I', NULL, 87, 78, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:33.976', 'I', NULL, 88, 105, 'Martes', '17:00:00', '19:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:50.717', 'I', NULL, 89, 90, 'Lunes', '21:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:52.39', 'I', NULL, 90, 95, 'Lunes', '19:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:56:57.42', 'I', NULL, 91, 54, 'Lunes', '17:00:00', '18:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:00.083', 'I', NULL, 92, 110, 'Martes', '19:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:01.084', 'I', NULL, 93, 80, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:12.224', 'I', NULL, 94, 54, 'Jueves', '17:00:00', '18:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:12.955', 'I', NULL, 95, 94, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:27.896', 'I', NULL, 96, 107, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:33.382', 'I', NULL, 97, 92, 'Lunes', '18:00:00', '19:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:54.56', 'I', NULL, 98, 93, 'Martes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:57:55.356', 'I', NULL, 99, 113, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:58:16.176', 'I', NULL, 100, 55, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:58:23.463', 'I', NULL, 101, 91, 'Viernes', '17:00:00', '18:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:58:38.014', 'I', NULL, 102, 56, 'Martes', '18:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:58:40.777', 'I', NULL, 103, 108, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:59:24.94', 'I', NULL, 104, 57, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:59:38.179', 'I', NULL, 105, 59, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 18:59:48.711', 'I', NULL, 106, 112, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:00:06.872', 'I', NULL, 107, 56, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:00:28.781', 'I', NULL, 108, 108, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:00:29.054', 'I', NULL, 109, 111, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:00:55.142', 'I', NULL, 110, 111, 'Viernes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:00:59.884', 'I', NULL, 111, 86, 'Jueves', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:01:18.348', 'I', NULL, 112, 61, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:01:22.446', 'I', NULL, 113, 96, 'Lunes', '20:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:01:55.539', 'I', NULL, 114, 114, 'Viernes', '20:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:01:57.781', 'I', NULL, 115, 88, 'Miercoles', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:02:09.153', 'I', NULL, 116, 88, 'Jueves', '19:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:03:32.744', 'I', NULL, 117, 116, 'Lunes', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:04:05.835', 'I', NULL, 118, 123, 'Lunes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:05:21.217', 'I', NULL, 119, 115, 'Martes', '17:00:00', '18:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:05:35.302', 'I', NULL, 120, 115, 'Miercoles', '17:00:00', '18:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:06:00.662', 'I', NULL, 121, 117, 'Martes', '18:00:00', '21:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:06:21.818', 'I', NULL, 122, 119, 'Miercoles', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:06:41.947', 'I', NULL, 123, 119, 'Viernes', '20:00:00', '22:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:09:14.496', 'I', NULL, 124, 120, 'Jueves', '18:00:00', '20:00:00');
INSERT INTO public_auditoria.logs_materias_horarios VALUES ('postgres', '2022-10-04 19:09:35.199', 'I', NULL, 125, 121, 'Viernes', '18:00:00', '20:00:00');


--
-- TOC entry 2083 (class 0 OID 27960)
-- Dependencies: 194
-- Data for Name: logs_parametros; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--



--
-- TOC entry 2084 (class 0 OID 27963)
-- Dependencies: 195
-- Data for Name: logs_profesores; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--

INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:21:06.741', 'D', NULL, 3, 1, '21508110', 'ZALACAIN VERONICA', 'vzalacain@gmail.com', '02323482302', 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:23:19.076', 'I', NULL, 8, 1, '17522715', 'ANTÚNEZ FERNANDO', 'ferantu31@hotmail.com', '1111111111111', 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:23:23.173', 'I', NULL, 9, 1, '12566071', 'ROMERO JUAN CARLOS', 'juancarlosjromer@gmail.com', '1', 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:23:24.815', 'I', NULL, 10, 1, '28179414', 'HERNANDEZ JESICA', 'hernandez.jesica@gmail.com', '1', 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:23:36.495', 'D', NULL, 8, 1, '17522715', 'ANTÚNEZ FERNANDO', 'ferantu31@hotmail.com', '1111111111111', 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:24:34.176', 'U', NULL, 9, 1, '12566071', 'ROMERO JUAN CARLOS', 'juancarlosjromer@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:24:38.146', 'U', NULL, 10, 1, '28179414', 'HERNANDEZ JESICA', 'hernandez.jesica@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:24:42.084', 'I', NULL, 11, 1, '17522715', 'ANTÚNEZ FERNANDO', 'ferantu31@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:25:28.056', 'I', NULL, 12, 1, '35726393', 'SCARAMELLA EMILIANA', 'emilianascaramella@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:25:44.593', 'I', NULL, 13, 1, '31259494', 'ASENZO MA VERNABÉ', 'bernabeasenzo@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:25:45.998', 'I', NULL, 14, 1, '13620552', 'KRAUTH ENRIQUE', 'quiquekrauth@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:26:19.4', 'I', NULL, 15, 1, '28473736', 'SCHOENFELD ALEJANDRO', 'alejandro.schoenfeld@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:26:30.544', 'I', NULL, 16, 1, '14097206', 'LAVORATO MARIA CECILIA', 'cecilialavorato@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:26:44.521', 'I', NULL, 17, 1, '22860328', 'AZZINNARI PABLO A', 'pablo_adrian1972@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:27:20.633', 'I', NULL, 18, 1, '22356132', 'LOPEZ CALCAGNO YANIL', 'yanil_lopezcalcagno@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:27:27.586', 'I', NULL, 19, 1, '13681943', 'BERGAGNA MIGUEL', 'mab57isft@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:27:33.002', 'I', NULL, 20, 1, '32850297', 'SCHOENFELD PAOLA', 'paolaschoenfeld@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:28:01.206', 'I', NULL, 21, 1, '24500298', 'LUQUE FELIX A', 'felix_luque@yahoo.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:28:09.385', 'I', NULL, 22, 1, '31777599', 'BIBOW SOLANA', 'solanabibow@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:28:44.607', 'I', NULL, 23, 1, '16618699', 'CAERO JOSE LUIS', 'josecaero@yahoo.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:28:46.281', 'I', NULL, 24, 1, '14789150', 'MACCARRONE ADRIANA', 'acmaccarrone@yahoo.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:29:19.286', 'I', NULL, 25, 1, '25778327', 'MARENGO HERNAN', 'marengohernan@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:29:26.348', 'I', NULL, 26, 1, '21508263', 'CANO MAURICIO', 'mauriciojcano@yahoo.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:29:27.244', 'I', NULL, 27, 1, '4791112', 'TARTAGLIA MA. TERESA', 'mariatsilvano@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:29:58.127', 'I', NULL, 28, 1, '25638872', 'MARTINEZ CARLA', 'carla.r.martinez@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:30:09.46', 'I', NULL, 29, 1, '16316263', 'TORRES ANA', 'anato963@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:30:27.49', 'I', NULL, 30, 1, '25153801', 'CARDOSO FATIMA', 'fatibeatrizcardozo@yahoo.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:30:41.851', 'I', NULL, 31, 1, '24142187', 'MARTINEZ SEBASTIAN', 'sebastianmartinez189turismo@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:30:48.951', 'I', NULL, 32, 1, '21435616', 'VAZQUEZ CLAUDIA', 'cvazquezbanchero@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:31:05.811', 'I', NULL, 33, 1, '24142552', 'CHERCOLES JAVIER', 'javiero@chercoles.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:31:28.395', 'I', NULL, 35, 1, '34153080', 'VERDEJO MAGDALENA', 'magdalenaverdejo@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:31:54.58', 'I', NULL, 36, 1, '27464737', 'CHIMIELEWSKI MARA', 'mara_natalia@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:32:10.686', 'I', NULL, 37, 1, '21548425', 'VERGAGNI SILVIA F.', 'fernandav@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:32:11.68', 'I', NULL, 38, 1, '14822435', 'MELLONI VIVIANA', 'a@a.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:32:40.724', 'I', NULL, 39, 1, '23087283', 'D´ALESSANDRO ANA C', 'acdalessandro@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:32:54.494', 'I', NULL, 40, 1, '7656708', 'MILANIESI OSCAR', 'oscarmilanesi189turismo@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:33:27.771', 'I', NULL, 41, 1, '17063499', 'DEL BUONO MA ISABEL', 'mdelbuono17@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:33:32.943', 'I', NULL, 42, 1, '17119257', 'PERAZZO PATRICIA', 'patriciapuncel@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:34:08.542', 'I', NULL, 43, 1, '24142364', 'DIAZ MARA LORENA', 'fausta@live.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:34:09.291', 'I', NULL, 44, 1, '22154641', 'PERELLO MARIO', 'mperello04@yahoo.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:34:44.963', 'I', NULL, 45, 1, '25136186', 'DOMINGUEZ MARINA', 'domingm2@yahoo.com.at', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:35:06.012', 'I', NULL, 46, 1, '105300005', 'PEREZ MA. DEL CARMEN', 'mariadelcarmenperez_52@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:35:36.881', 'I', NULL, 47, 1, '24142093', 'FERRARI LEONARDO', 'leonardo.cesar.ferrari@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:35:54.111', 'I', NULL, 48, 1, '30401629', 'POSTOLOW NADIA', 'nadiapostolow@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:36:25.967', 'I', NULL, 49, 1, '23775366', 'GAITAN MA FERNANDA', 'fernandagaitan2002@yahoo.com.ar', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:36:35.181', 'I', NULL, 50, 1, '24500003', 'RAMIREZ ROMINA', 'romina.ramirez.turismo@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:37:08.844', 'I', NULL, 51, 1, '32640035', 'GHIONI MARIA CARLA', 'contodaslasletras@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:37:22.197', 'I', NULL, 52, 1, '27735240', 'REY ESTEBAN', 'estebanrey2105@gmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:37:49.944', 'I', NULL, 53, 1, '18457000', 'GIULIANO ALBERTO', 'giulianopro10@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:38:00.003', 'I', NULL, 54, 1, '35025063', 'RIZZO ROCIO', 'rociobelenrizzo@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:38:20.996', 'I', NULL, 55, 1, '16029902', 'HEIRAS OSCAR', 'oscarheiras@hotmail.com', NULL, 1);
INSERT INTO public_auditoria.logs_profesores VALUES ('postgres', '2022-10-03 20:38:30.962', 'I', NULL, 56, 1, '20967041', 'ROBLEDO MARCELO', 'rodomarce@gmail.com', NULL, 1);


--
-- TOC entry 2085 (class 0 OID 27966)
-- Dependencies: 196
-- Data for Name: logs_tipos_documento; Type: TABLE DATA; Schema: public_auditoria; Owner: postgres
--



--
-- TOC entry 2104 (class 0 OID 0)
-- Dependencies: 177
-- Name: alumnos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.alumnos_id_seq', 3, true);


--
-- TOC entry 2105 (class 0 OID 0)
-- Dependencies: 181
-- Name: asuetos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.asuetos_id_seq', 1, true);


--
-- TOC entry 2106 (class 0 OID 0)
-- Dependencies: 164
-- Name: carreras_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.carreras_id_seq', 19, true);


--
-- TOC entry 2107 (class 0 OID 0)
-- Dependencies: 175
-- Name: estados_alumnos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.estados_alumnos_id_seq', 4, true);


--
-- TOC entry 2108 (class 0 OID 0)
-- Dependencies: 166
-- Name: institutos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.institutos_id_seq', 3, true);


--
-- TOC entry 2109 (class 0 OID 0)
-- Dependencies: 179
-- Name: localidades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.localidades_id_seq', 34, true);


--
-- TOC entry 2110 (class 0 OID 0)
-- Dependencies: 169
-- Name: materias_horarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.materias_horarios_id_seq', 125, true);


--
-- TOC entry 2111 (class 0 OID 0)
-- Dependencies: 170
-- Name: materias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.materias_id_seq', 132, true);


--
-- TOC entry 2112 (class 0 OID 0)
-- Dependencies: 185
-- Name: parametros_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parametros_id_seq', 1, true);


--
-- TOC entry 2113 (class 0 OID 0)
-- Dependencies: 172
-- Name: profesores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.profesores_id_seq', 56, true);


--
-- TOC entry 2114 (class 0 OID 0)
-- Dependencies: 174
-- Name: tipos_documento_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_documento_id_seq', 5, true);


--
-- TOC entry 1888 (class 2606 OID 27920)
-- Name: carreras carreras_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carreras
    ADD CONSTRAINT carreras_uk UNIQUE (id_instituto, descripcion, plan);


--
-- TOC entry 1916 (class 2606 OID 19024)
-- Name: alumnos pk_id_alumnos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumnos
    ADD CONSTRAINT pk_id_alumnos PRIMARY KEY (id);


--
-- TOC entry 1928 (class 2606 OID 19064)
-- Name: asuetos pk_id_asuetos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asuetos
    ADD CONSTRAINT pk_id_asuetos PRIMARY KEY (id);


--
-- TOC entry 1890 (class 2606 OID 18959)
-- Name: carreras pk_id_carreras; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carreras
    ADD CONSTRAINT pk_id_carreras PRIMARY KEY (id);


--
-- TOC entry 1912 (class 2606 OID 19014)
-- Name: estados_alumnos pk_id_estados_alumnos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estados_alumnos
    ADD CONSTRAINT pk_id_estados_alumnos PRIMARY KEY (id);


--
-- TOC entry 1892 (class 2606 OID 18961)
-- Name: institutos pk_id_institutos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institutos
    ADD CONSTRAINT pk_id_institutos PRIMARY KEY (id);


--
-- TOC entry 1922 (class 2606 OID 19041)
-- Name: localidades pk_id_localidades; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.localidades
    ADD CONSTRAINT pk_id_localidades PRIMARY KEY (id);


--
-- TOC entry 1896 (class 2606 OID 18963)
-- Name: materias pk_id_materias; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias
    ADD CONSTRAINT pk_id_materias PRIMARY KEY (id);


--
-- TOC entry 1900 (class 2606 OID 18965)
-- Name: materias_horarios pk_id_materias_horarios; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias_horarios
    ADD CONSTRAINT pk_id_materias_horarios PRIMARY KEY (id);


--
-- TOC entry 1932 (class 2606 OID 27445)
-- Name: parametros pk_id_parametros; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametros
    ADD CONSTRAINT pk_id_parametros PRIMARY KEY (id);


--
-- TOC entry 1904 (class 2606 OID 18967)
-- Name: profesores pk_id_profesores; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profesores
    ADD CONSTRAINT pk_id_profesores PRIMARY KEY (id);


--
-- TOC entry 1908 (class 2606 OID 18969)
-- Name: tipos_documento pk_id_tipos_doc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_documento
    ADD CONSTRAINT pk_id_tipos_doc PRIMARY KEY (id);


--
-- TOC entry 1930 (class 2606 OID 19066)
-- Name: asuetos uk_asuetos_fecha; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asuetos
    ADD CONSTRAINT uk_asuetos_fecha UNIQUE (fecha);


--
-- TOC entry 1902 (class 2606 OID 18971)
-- Name: materias_horarios uk_carrera_horarios; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias_horarios
    ADD CONSTRAINT uk_carrera_horarios UNIQUE (id_materia, dia_semana, hora_desde);


--
-- TOC entry 1924 (class 2606 OID 19056)
-- Name: localidades uk_cp_localidades; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.localidades
    ADD CONSTRAINT uk_cp_localidades UNIQUE (cp);


--
-- TOC entry 1914 (class 2606 OID 19016)
-- Name: estados_alumnos uk_desc_estados_alumnos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estados_alumnos
    ADD CONSTRAINT uk_desc_estados_alumnos UNIQUE (descripcion);


--
-- TOC entry 1894 (class 2606 OID 18973)
-- Name: institutos uk_desc_institutos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institutos
    ADD CONSTRAINT uk_desc_institutos UNIQUE (descripcion);


--
-- TOC entry 1926 (class 2606 OID 19043)
-- Name: localidades uk_desc_localidades; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.localidades
    ADD CONSTRAINT uk_desc_localidades UNIQUE (descripcion);


--
-- TOC entry 1898 (class 2606 OID 27933)
-- Name: materias uk_desc_materias; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias
    ADD CONSTRAINT uk_desc_materias UNIQUE (id_carrera, id_profesor, descripcion);


--
-- TOC entry 1910 (class 2606 OID 18977)
-- Name: tipos_documento uk_desc_tipos_doc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_documento
    ADD CONSTRAINT uk_desc_tipos_doc UNIQUE (descripcion);


--
-- TOC entry 1918 (class 2606 OID 19028)
-- Name: alumnos uk_legajo_alumnos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumnos
    ADD CONSTRAINT uk_legajo_alumnos UNIQUE (legajo);


--
-- TOC entry 1920 (class 2606 OID 19026)
-- Name: alumnos uk_tipo_nro_doc_alumnos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumnos
    ADD CONSTRAINT uk_tipo_nro_doc_alumnos UNIQUE (id_tipo_documento, numero_documento);


--
-- TOC entry 1906 (class 2606 OID 18981)
-- Name: profesores uk_tipo_nro_doc_profesores; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profesores
    ADD CONSTRAINT uk_tipo_nro_doc_profesores UNIQUE (id_tipo_documento, numero_documento);


--
-- TOC entry 1948 (class 2620 OID 27980)
-- Name: alumnos tauditoria_alumnos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_alumnos AFTER INSERT OR DELETE OR UPDATE ON public.alumnos FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_alumnos();


--
-- TOC entry 1950 (class 2620 OID 27981)
-- Name: asuetos tauditoria_asuetos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_asuetos AFTER INSERT OR DELETE OR UPDATE ON public.asuetos FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_asuetos();


--
-- TOC entry 1941 (class 2620 OID 27982)
-- Name: carreras tauditoria_carreras; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_carreras AFTER INSERT OR DELETE OR UPDATE ON public.carreras FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_carreras();


--
-- TOC entry 1947 (class 2620 OID 27983)
-- Name: estados_alumnos tauditoria_estados_alumnos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_estados_alumnos AFTER INSERT OR DELETE OR UPDATE ON public.estados_alumnos FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_estados_alumnos();


--
-- TOC entry 1942 (class 2620 OID 27984)
-- Name: institutos tauditoria_institutos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_institutos AFTER INSERT OR DELETE OR UPDATE ON public.institutos FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_institutos();


--
-- TOC entry 1949 (class 2620 OID 27985)
-- Name: localidades tauditoria_localidades; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_localidades AFTER INSERT OR DELETE OR UPDATE ON public.localidades FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_localidades();


--
-- TOC entry 1943 (class 2620 OID 27986)
-- Name: materias tauditoria_materias; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_materias AFTER INSERT OR DELETE OR UPDATE ON public.materias FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_materias();


--
-- TOC entry 1944 (class 2620 OID 27987)
-- Name: materias_horarios tauditoria_materias_horarios; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_materias_horarios AFTER INSERT OR DELETE OR UPDATE ON public.materias_horarios FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_materias_horarios();


--
-- TOC entry 1951 (class 2620 OID 27988)
-- Name: parametros tauditoria_parametros; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_parametros AFTER INSERT OR DELETE OR UPDATE ON public.parametros FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_parametros();


--
-- TOC entry 1945 (class 2620 OID 27989)
-- Name: profesores tauditoria_profesores; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_profesores AFTER INSERT OR DELETE OR UPDATE ON public.profesores FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_profesores();


--
-- TOC entry 1946 (class 2620 OID 27990)
-- Name: tipos_documento tauditoria_tipos_documento; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tauditoria_tipos_documento AFTER INSERT OR DELETE OR UPDATE ON public.tipos_documento FOR EACH ROW EXECUTE PROCEDURE public_auditoria.sp_tipos_documento();


--
-- TOC entry 1936 (class 2606 OID 18982)
-- Name: materias_horarios fk_horarios_materias; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias_horarios
    ADD CONSTRAINT fk_horarios_materias FOREIGN KEY (id_materia) REFERENCES public.materias(id);


--
-- TOC entry 1934 (class 2606 OID 18987)
-- Name: materias fk_id_carreras_mat; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias
    ADD CONSTRAINT fk_id_carreras_mat FOREIGN KEY (id_carrera) REFERENCES public.carreras(id);


--
-- TOC entry 1940 (class 2606 OID 19044)
-- Name: alumnos fk_id_localidad_alumnos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumnos
    ADD CONSTRAINT fk_id_localidad_alumnos FOREIGN KEY (id_localidad) REFERENCES public.localidades(id);


--
-- TOC entry 1938 (class 2606 OID 19049)
-- Name: profesores fk_id_localidad_profesores; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profesores
    ADD CONSTRAINT fk_id_localidad_profesores FOREIGN KEY (id_localidad) REFERENCES public.localidades(id);


--
-- TOC entry 1935 (class 2606 OID 18992)
-- Name: materias fk_id_profesor_mat; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materias
    ADD CONSTRAINT fk_id_profesor_mat FOREIGN KEY (id_profesor) REFERENCES public.profesores(id);


--
-- TOC entry 1939 (class 2606 OID 19029)
-- Name: alumnos fk_id_tipodoc_alumno; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alumnos
    ADD CONSTRAINT fk_id_tipodoc_alumno FOREIGN KEY (id_tipo_documento) REFERENCES public.tipos_documento(id);


--
-- TOC entry 1933 (class 2606 OID 18997)
-- Name: carreras fk_instituto_carreras; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carreras
    ADD CONSTRAINT fk_instituto_carreras FOREIGN KEY (id_instituto) REFERENCES public.institutos(id);


--
-- TOC entry 1937 (class 2606 OID 19002)
-- Name: profesores fk_tipos_doc_profes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profesores
    ADD CONSTRAINT fk_tipos_doc_profes FOREIGN KEY (id_tipo_documento) REFERENCES public.tipos_documento(id);


--
-- TOC entry 2092 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2022-10-04 19:44:33

--
-- PostgreSQL database dump complete
--

