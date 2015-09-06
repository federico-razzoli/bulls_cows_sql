/*
        Copright 2015, Federico Razzoli
        
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU Affero General Public License as published by
        the Free Software Foundation, version 3 of the License.
        
        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU Affero General Public License for more details.
        
        You should have received a copy of the GNU Affero General Public License
        along with this program.  If not, see <http://www.gnu.org/licenses/>.  
*/


\W


INSTALL SONAME 'ha_sequence';


CREATE DATABASE bulls_cows
        DEFAULT CHARACTER SET utf8;
USE bulls_cows;


DELIMITER ||

DROP PROCEDURE IF EXISTS new;
CREATE PROCEDURE new()
        MODIFIES SQL DATA
        COMMENT 'Start new game'
BEGIN
        DECLARE v_cur_digit TINYINT UNSIGNED DEFAULT NULL;
        DECLARE i TINYINT UNSIGNED DEFAULT 3;
        
        CREATE OR REPLACE TEMPORARY TABLE digit
                ENGINE = MEMORY
                SELECT seq AS n FROM seq_1_to_9;
        
        SET @digits := (SELECT n FROM digit ORDER BY RAND() LIMIT 1);
        DELETE FROM digit WHERE n = @digits;
        INSERT INTO digit VALUES (0);
        
        WHILE i > 0 DO
                SET v_cur_digit := (SELECT n FROM digit ORDER BY RAND() LIMIT 1);
                DELETE FROM digit WHERE n = v_cur_digit;
                SET @digits := CONCAT(@digits, v_cur_digit);
                
                SET i := i - 1;
        END WHILE;
        
        DROP TEMPORARY TABLE digit;
        
        SELECT '\nOK... try to guess!\n' AS `Message`;
END ||


DROP PROCEDURE IF EXISTS guess;
CREATE PROCEDURE guess(IN p_number CHAR(4))
        MODIFIES SQL DATA
        COMMENT 'Guess secret number'
BEGIN
        DECLARE error_message VARCHAR(100) DEFAULT NULL;
        
        -- reset score
        SET @bulls  := 0;
        SET @cows   := 0;
        
        IF p_number IS NULL OR p_number NOT REGEXP '[[:digit:]]{4}' THEN
                SET error_message := 'Please enter 4 digits';
        ELSEIF @allow_twin_cows IS NULL OR @allow_twin_cows IS FALSE THEN
                CREATE OR REPLACE TEMPORARY TABLE last_digits
                (
                        n SMALLINT UNSIGNED
                )
                        ENGINE = MEMORY
                ;
                INSERT IGNORE INTO last_digits SELECT SUBSTRING(p_number FROM 1 FOR 1);
                INSERT IGNORE INTO last_digits SELECT SUBSTRING(p_number FROM 2 FOR 1);
                INSERT IGNORE INTO last_digits SELECT SUBSTRING(p_number FROM 3 FOR 1);
                INSERT IGNORE INTO last_digits SELECT SUBSTRING(p_number FROM 4 FOR 1);
                
                IF (SELECT COUNT(DISTINCT n) FROM last_digits) <> 4 THEN
                        SET error_message := 'Twin cows not allowed!\nAll digits must be different';
                END IF;
                
                DROP TEMPORARY TABLE last_digits;
        END IF;
        
        IF error_message IS NOT NULL THEN
                SELECT CONCAT('\n', error_message, '\n') AS `ERROR`;
        ELSE
                BEGIN
                        DECLARE secret_i, guess_i TINYINT UNSIGNED DEFAULT 1;
                        DECLARE secret_cur, guess_cur CHAR(1) DEFAULT NULL;
                        
                        WHILE secret_i < 5 DO
                                SET secret_cur  := SUBSTRING(@digits FROM secret_i FOR 1);
                                SET guess_cur   := SUBSTRING(p_number FROM secret_i FOR 1);
                                
                                IF guess_cur = secret_cur THEN
                                        SET @bulls := @bulls + 1;
                                ELSE
                                        SET guess_i := 1;
                                        
                                        WHILE guess_i < 5 DO
                                                SET guess_cur := SUBSTRING(p_number FROM guess_i FOR 1);
                                                
                                                IF guess_cur = secret_cur THEN
                                                        SET @cows := @cows + 1;
                                                END IF;
                                                
                                                SET guess_i := guess_i + 1;
                                        END WHILE;
                                END IF;
                                
                                SET secret_i := secret_i + 1;
                        END WHILE;
                END;
                
                IF @bulls = 4 THEN
                        SELECT '\n4 BULLZ!\n\nCongratulations, pal!\n' AS `Message`;
                ELSEIF @bulls = 0 AND @cows = 0 THEN
                        SELECT '\n0 bulls, 0 cows...\n\nHow sad. Try again!\n' AS `Message`;
                ELSE
                        SELECT @bulls AS `bulls`, @cows AS `cows`;
                END IF;
        END IF;
END ||

DROP PROCEDURE IF EXISTS help;
CREATE PROCEDURE help()
        MODIFIES SQL DATA
        COMMENT 'How to play'
BEGIN
        SELECT CONCAT(
                          '\n'
                        , 'BULLS AND COWS\n'
                        , '==============\n'
                        , '\n'
                        , 'I''ll think a 4-digits number. You try to guess.\n'
                        , 'For each digit you guess, you score 1 bull if it''s in the right position,\n'
                        , 'or 1 cow if it isn''t.\n'
                        , '\n'
                        , 'For example: I think 1234, you think 1489. You score:'
                        , '1 bull, because 1 is in the right position;\n'
                        , '1 cow, because 4 is correct, but in the wrong position.\n'
                        , '\n'
                        , 'To make me think a new number, type:\n'
                        , 'CALL new();\n', '\n'
                        , 'To try guessing the secret number, type:\n'
                        , 'CALL guess(''1234'');\n'
                        , '\n'
                        , 'You don''t want to call new() each time\n'
                        , 'if you want to retry, or if you''re playing with someone else.\n'
                ) AS `Message`;
END ||

DELIMITER ;


