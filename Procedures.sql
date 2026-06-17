SET SERVEROUTPUT ON;

-- =====================================================
-- DROP PROCEDURES IF THEY EXIST
-- =====================================================
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE ADD_GUEST';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE CREATE_RESERVATION';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE ASSIGN_ROOM';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE CALC_SERVICE_TOTAL';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE RESERVATION_TOTAL_PROC';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE ADD_SERVICE_RECORD';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE ADD_PAYMENT';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4043 THEN RAISE; END IF;
END;
/

-- =====================================================
-- PROCEDURE 1: ADD_GUEST  
-- =====================================================
CREATE OR REPLACE PROCEDURE ADD_GUEST (
    p_name        IN VARCHAR2,
    p_contact_no  IN VARCHAR2,
    p_email       IN VARCHAR2,
    p_address     IN VARCHAR2,
    p_guest_id    OUT NUMBER
)
IS
BEGIN
    SELECT GUEST_SEQ.NEXTVAL INTO p_guest_id FROM dual;

    INSERT INTO GUEST (
        GUEST_ID, NAME, CONTACT_NO, EMAIL, ADDRESS
    ) VALUES (
        p_guest_id, p_name, p_contact_no, p_email, p_address
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- =====================================================
-- PROCEDURE 2: CREATE_RESERVATION
-- =====================================================
CREATE OR REPLACE PROCEDURE CREATE_RESERVATION (
    p_guest_id       IN NUMBER,
    p_checkin_date   IN DATE,
    p_checkout_date  IN DATE,
    p_room_id        IN NUMBER,
    p_reservation_id OUT NUMBER
)
IS  
BEGIN
    SELECT RESERVATION_SEQ.NEXTVAL INTO p_reservation_id FROM dual;

    INSERT INTO RESERVATION (
        RESERVATION_ID, GUEST_ID, RESERVATION_DATE,
        CHECKIN_DATE, CHECKOUT_DATE, STATUS
    ) VALUES (
        p_reservation_id, p_guest_id, SYSDATE,
        p_checkin_date, p_checkout_date, 'BOOKED'
    );

    INSERT INTO RESERVATION_ROOM (
        RESERVATION_ID, ROOM_ID
    ) VALUES (
        p_reservation_id, p_room_id
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20024,
            'Error creating reservation: ' || SQLERRM);
END;
/

-- =====================================================
-- PROCEDURE 3: ASSIGN_ROOM
-- =====================================================
CREATE OR REPLACE PROCEDURE ASSIGN_ROOM (
    p_reservation_id IN NUMBER,
    p_room_id        IN NUMBER
)
IS
BEGIN
    INSERT INTO RESERVATION_ROOM (RESERVATION_ID, ROOM_ID)
    VALUES (p_reservation_id, p_room_id);

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20402,
            'Error in ASSIGN_ROOM: ' || SQLERRM);
END;
/

-- =====================================================
-- PROCEDURE 4: CALC_SERVICE_TOTAL
-- =====================================================
CREATE OR REPLACE PROCEDURE CALC_SERVICE_TOTAL (
    p_reservation_id IN NUMBER,
    p_service_total  OUT NUMBER
)
IS
BEGIN
    SELECT NVL(SUM(SR.QUANTITY * S.SERVICE_CHARGE), 0)
    INTO p_service_total
    FROM SERVICE_RECORD SR
    JOIN SERVICE S ON SR.SERVICE_ID = S.SERVICE_ID
    WHERE SR.RESERVATION_ID = p_reservation_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20700,
            'Error calculating services: ' || SQLERRM);
END;
/

-- =====================================================
-- PROCEDURE 5: RESERVATION_TOTAL_PROC
-- =====================================================
CREATE OR REPLACE PROCEDURE RESERVATION_TOTAL_PROC (
    p_reservation_id IN NUMBER,
    p_final_total    OUT NUMBER
)
IS
    v_room_charge    NUMBER := 0;
    v_service_charge NUMBER := 0;
    v_in   DATE;
    v_out  DATE;
BEGIN
    SELECT CHECKIN_DATE, CHECKOUT_DATE
    INTO v_in, v_out
    FROM RESERVATION
    WHERE RESERVATION_ID = p_reservation_id;

    SELECT NVL(SUM(RT.RATE * (v_out - v_in)), 0)
    INTO v_room_charge
    FROM RESERVATION_ROOM RR
    JOIN ROOM RM ON RR.ROOM_ID = RM.ROOM_ID
    JOIN ROOM_TYPE RT ON RM.ROOM_TYPE_ID = RT.ROOM_TYPE_ID
    WHERE RR.RESERVATION_ID = p_reservation_id;

    CALC_SERVICE_TOTAL(p_reservation_id, v_service_charge);

    p_final_total := v_room_charge + v_service_charge;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20702,
            'Error calculating totals: ' || SQLERRM);
END;
/

-- =====================================================
-- PROCEDURE 6: ADD_SERVICE_RECORD
-- =====================================================
CREATE OR REPLACE PROCEDURE ADD_SERVICE_RECORD (
    p_reservation_id IN NUMBER,
    p_service_id     IN NUMBER,
    p_staff_id       IN NUMBER,
    p_room_id        IN NUMBER,
    p_quantity       IN NUMBER,
    p_record_id      OUT NUMBER
)
IS
BEGIN
    SELECT SERVICE_RECORD_SEQ.NEXTVAL
    INTO p_record_id
    FROM dual;

    INSERT INTO SERVICE_RECORD (
        SERVICE_RECORD_ID, RESERVATION_ID, SERVICE_ID,
        STAFF_ID, ROOM_ID, QUANTITY
    ) VALUES (
        p_record_id, p_reservation_id, p_service_id,
        p_staff_id, p_room_id, p_quantity
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20606,
            'Error adding service: ' || SQLERRM);
END;
/

-- =====================================================
-- PROCEDURE 7: ADD_PAYMENT
-- =====================================================
CREATE OR REPLACE PROCEDURE ADD_PAYMENT (
    p_reservation_id IN NUMBER,
    p_amount         IN NUMBER,
    p_method         IN VARCHAR2,
    p_payment_id     OUT NUMBER
)
IS
BEGIN
    SELECT PAYMENT_SEQ.NEXTVAL
    INTO p_payment_id
    FROM dual;

    INSERT INTO PAYMENT (
        PAYMENT_ID, RESERVATION_ID, AMOUNT,
        PAYMENT_METHOD, PAYMENT_DATE
    ) VALUES (
        p_payment_id, p_reservation_id, p_amount,
        UPPER(p_method), SYSDATE
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20504,
            'Error adding payment: ' || SQLERRM);
END;
/
