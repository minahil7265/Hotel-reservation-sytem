SET SERVEROUTPUT ON;

-- =====================================================
-- DROP TRIGGERS IF THEY EXIST
-- =====================================================
DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_NO_DOUBLE_BOOKING';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_UPDATE_ROOM_STATUS';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_VALIDATE_SERVICE_ROOM';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_FREE_ROOM';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_PREVENT_GUEST_DELETE';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

DECLARE
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER TRG_PAYMENT_CHECK';
EXCEPTION
    WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

-- =====================================================
-- TRIGGER 1: Prevent Double Booking
-- =====================================================
CREATE OR REPLACE TRIGGER TRG_NO_DOUBLE_BOOKING
BEFORE INSERT OR UPDATE ON RESERVATION_ROOM
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_checkin DATE;
    v_checkout DATE;
BEGIN
    SELECT CHECKIN_DATE, CHECKOUT_DATE
    INTO v_checkin, v_checkout
    FROM RESERVATION
    WHERE RESERVATION_ID = :NEW.RESERVATION_ID;

    SELECT COUNT(*)
    INTO v_count
    FROM RESERVATION_ROOM RR
    JOIN RESERVATION R ON RR.RESERVATION_ID = R.RESERVATION_ID
    WHERE RR.ROOM_ID = :NEW.ROOM_ID
      AND R.STATUS IN ('BOOKED','CHECKED_IN')
      AND v_checkin < R.CHECKOUT_DATE
      AND v_checkout > R.CHECKIN_DATE;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Room already booked for the selected dates.');
    END IF;
END;
/

-- =====================================================
-- TRIGGER 2: Update Room Status to RESERVED after Assignment
-- =====================================================
CREATE OR REPLACE TRIGGER TRG_UPDATE_ROOM_STATUS
AFTER INSERT ON RESERVATION_ROOM
FOR EACH ROW
BEGIN
    UPDATE ROOM
    SET STATUS = 'RESERVED'
    WHERE ROOM_ID = :NEW.ROOM_ID;
END;
/

-- =====================================================
-- TRIGGER 3: Ensure Service is Added for Correct Room
-- =====================================================
CREATE OR REPLACE TRIGGER TRG_VALIDATE_SERVICE_ROOM
BEFORE INSERT ON SERVICE_RECORD
FOR EACH ROW
DECLARE
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_exists
    FROM RESERVATION_ROOM
    WHERE RESERVATION_ID = :NEW.RESERVATION_ID
      AND ROOM_ID = :NEW.ROOM_ID;

    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Service room does not match any room in this reservation.'
        );
    END IF;
END;
/

-- =====================================================
-- TRIGGER 4: Free Room on Checkout
-- =====================================================
CREATE OR REPLACE TRIGGER TRG_FREE_ROOM
AFTER UPDATE OF STATUS ON RESERVATION
FOR EACH ROW
WHEN (NEW.STATUS = 'CHECKED_OUT')
BEGIN
    UPDATE ROOM RM
    SET STATUS = 'AVAILABLE'
    WHERE RM.ROOM_ID IN (
        SELECT ROOM_ID
        FROM RESERVATION_ROOM
        WHERE RESERVATION_ID = :NEW.RESERVATION_ID
    )
    AND NOT EXISTS (
        SELECT 1
        FROM RESERVATION R
        JOIN RESERVATION_ROOM RR
        ON R.RESERVATION_ID = RR.RESERVATION_ID
        WHERE RR.ROOM_ID = RM.ROOM_ID
        AND R.STATUS IN ('BOOKED','CHECKED_IN')
        AND R.RESERVATION_ID != :NEW.RESERVATION_ID
    );
END;
/

-- =====================================================
-- TRIGGER 5: Prevent Deleting Guest with Active Reservations
-- =====================================================
CREATE OR REPLACE TRIGGER TRG_PREVENT_GUEST_DELETE
BEFORE DELETE ON GUEST
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM RESERVATION
    WHERE GUEST_ID = :OLD.GUEST_ID
      AND STATUS IN ('BOOKED','CHECKED_IN');

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Cannot delete guest with active reservations.');
    END IF;
END;
/

-- =====================================================
-- TRIGGER 6: Prevent Payment for Cancelled Reservations
-- =====================================================
CREATE OR REPLACE TRIGGER TRG_PAYMENT_CHECK
BEFORE INSERT ON PAYMENT
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
BEGIN
    SELECT STATUS INTO v_status
    FROM RESERVATION
    WHERE RESERVATION_ID = :NEW.RESERVATION_ID;

    IF v_status = 'CANCELLED' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Cannot make payment for a cancelled reservation.');
    END IF;
END;
/
-- =====================================================
-- TRIGGER 7: Set Room Available on Early Checkout
-- =====================================================
CREATE OR REPLACE TRIGGER TRG_ROOM_EARLY_CHECKOUT
AFTER UPDATE OF CHECKOUT_DATE ON RESERVATION
FOR EACH ROW
WHEN (NEW.CHECKOUT_DATE < OLD.CHECKOUT_DATE)
BEGIN
    UPDATE ROOM
    SET STATUS = 'AVAILABLE'
    WHERE ROOM_ID IN (
        SELECT ROOM_ID
        FROM RESERVATION_ROOM
        WHERE RESERVATION_ID = :NEW.RESERVATION_ID
    );
END;
/
