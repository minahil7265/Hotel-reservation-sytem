-- =============================================
-- INDEXES
-- =============================================

-- 1) Fast lookup of reservations by guest and status
CREATE INDEX IDX_RESERVATION_GUEST_STATUS 
ON RESERVATION(GUEST_ID, STATUS);

-- 2) Fast lookup of rooms by hotel and status
CREATE INDEX IDX_ROOM_HOTEL_STATUS 
ON ROOM(HOTEL_ID, STATUS);

-- 3) Speed up joins from PAYMENT -> RESERVATION
CREATE INDEX IDX_PAYMENT_RESERVATION
ON PAYMENT(RESERVATION_ID);

-- 4) Speed up service history queries
CREATE INDEX IDX_SR_RESERVATION_SERVICE
ON SERVICE_RECORD(RESERVATION_ID, SERVICE_ID);


-- =============================================
-- VIEWS
-- =============================================

-- 1) Current Occupancy View
CREATE OR REPLACE VIEW VW_CURRENT_OCCUPANCY AS
SELECT r.RESERVATION_ID,
       g.GUEST_ID,
       g.NAME AS GUEST_NAME,
       h.HOTEL_ID,
       h.NAME AS HOTEL_NAME,
       rm.ROOM_ID,
       rt.NAME AS ROOM_TYPE,
       res.CHECKIN_DATE,
       res.CHECKOUT_DATE,
       res.STATUS AS RESERVATION_STATUS
FROM RESERVATION res
JOIN RESERVATION_ROOM rr 
    ON rr.RESERVATION_ID = res.RESERVATION_ID
JOIN ROOM rm 
    ON rm.ROOM_ID = rr.ROOM_ID
JOIN ROOM_TYPE rt 
    ON rt.ROOM_TYPE_ID = rm.ROOM_TYPE_ID
JOIN GUEST g 
    ON g.GUEST_ID = res.GUEST_ID
JOIN HOTEL h 
    ON h.HOTEL_ID = rm.HOTEL_ID
WHERE res.STATUS = 'CHECKED_IN';


-- 2) Guest Service History View
CREATE OR REPLACE VIEW VW_GUEST_SERVICES AS
SELECT sr.SERVICE_RECORD_ID,
       sr.RESERVATION_ID,
       g.GUEST_ID,
       g.NAME AS GUEST_NAME,
       s.SERVICE_ID,
       s.NAME AS SERVICE_NAME,
       s.SERVICE_CHARGE,
       sr.QUANTITY,
       (s.SERVICE_CHARGE * sr.QUANTITY) AS TOTAL_CHARGE,
       st.NAME AS STAFF_NAME,
       sr.ROOM_ID
FROM SERVICE_RECORD sr
JOIN SERVICE s 
    ON s.SERVICE_ID = sr.SERVICE_ID
JOIN RESERVATION r 
    ON r.RESERVATION_ID = sr.RESERVATION_ID
JOIN GUEST g 
    ON g.GUEST_ID = r.GUEST_ID
LEFT JOIN STAFF st 
    ON st.STAFF_ID = sr.STAFF_ID;