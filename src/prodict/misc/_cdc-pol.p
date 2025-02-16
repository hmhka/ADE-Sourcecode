&Scoped-define WINDOW-NAME CURRENT-WINDOW
&Scoped-define FRAME-NAME Select-Frame
/*************************************************************/
/* Copyright (c) 1984-2017 by Progress Software Corporation  */
/*                                                           */
/* All rights reserved.  No part of this program or document */
/* may be  reproduced in  any form  or by  any means without */
/* permission in writing from PROGRESS Software Corporation. */
/*************************************************************/
/*------------------------------------------------------------------------

  File: prodict/misc/_cdc-pol.p

  Description: Filter dialog for CDC Policies.

  Input Parameters:
      <none>

  Output Parameters:
      <none>

  Author: Kunal Berlia

  Created: October 26, 2016
  History: 
  
------------------------------------------------------------------------*/
/*          This .W file was created with the Progress AppBuilder.       */
/*----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

/* Parameters Definitions ---                                           */

{prodict/misc/cdc-tts.i}
{prodict/user/uservar.i}

/* Local Variable Definitions ---                                       */

DEFINE QUERY qPolicy FOR ttPolicy SCROLLING.

DEFINE BROWSE bPolicy QUERY qPolicy 
    DISPLAY ttPolicy.tcPolName     FORMAT "X(14)"  COLUMN-LABEL "Policy Name"
            ttPolicy.tcTableName   FORMAT "X(14)"  COLUMN-LABEL "Table Name"
	        ttpolicy.tcPolInstance                 COLUMN-LABEL "Policy Instance"
            ttpolicy.tcChangeTblName               COLUMN-LABEL "Change Table Name"

    WITH &IF "{&WINDOW-SYSTEM}" <> "TTY" 
           &THEN 11 &ELSE 6 
         &ENDIF DOWN WIDTH 70 MULTIPLE.

DEFINE VARIABLE giPolicies AS INTEGER     NO-UNDO.

DEFINE VARIABLE lImmedDisp AS LOGICAL     NO-UNDO.
DEFINE VARIABLE v-rowid    AS ROWID       NO-UNDO.

/* ********************  Preprocessor Definitions  ******************** */

&Scoped-define PROCEDURE-TYPE Dialog-Box
&Scoped-define DB-AWARE no

&Scoped-define LAYOUT-VARIABLE CURRENT-WINDOW-layout

/* Name of designated FRAME-NAME and/or first browse and/or first query */
&Scoped-define FRAME-NAME Select-Frame

/* Standard List Definitions                                            */
&Scoped-Define ENABLED-OBJECTS RECT-1 tbSelectAll tbPending btnOK btnCancel 
&Scoped-Define DISPLAYED-OBJECTS tbSelectAll  tbPending

/* Define a variable to store the name of the active layout.            */
DEFINE VAR CURRENT-WINDOW-layout AS CHAR INITIAL "Master Layout":U NO-UNDO.

/* ***********************  Control Definitions  ********************** */

/* Define a dialog box                                                  */

/* Definitions of the field level widgets                               */
DEFINE BUTTON btnCancel
     LABEL "Cancel" 
     &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN SIZE 11 BY 1
     &ELSE SIZE 11 BY .95 &ENDIF
     BGCOLOR 8 .

&IF "{&WINDOW-SYSTEM}" NE "TTY" &THEN
  DEFINE BUTTON BtnHelp DEFAULT 
     LABEL "&Help" 
     &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN SIZE 11 BY 1
     &ELSE SIZE 11 BY .95 &ENDIF
     BGCOLOR 8 .
&ENDIF

DEFINE BUTTON btnOK
     LABEL "OK" 
     &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN SIZE 11 BY 1
     &ELSE SIZE 11 BY .95 &ENDIF
     BGCOLOR 8.

DEFINE RECTANGLE RECT-1
     EDGE-PIXELS 2 GRAPHIC-EDGE  NO-FILL 
     &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN SIZE 66 BY 1
     &ELSE SIZE 65.6 BY 1.38 &ENDIF.

DEFINE VARIABLE tbSelectAll AS LOGICAL INITIAL no 
     LABEL "All Current" 
     VIEW-AS TOGGLE-BOX
     &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN SIZE 13.4 BY .81
     &ELSE SIZE 13.4 BY .81 &ENDIF NO-UNDO.

DEFINE VARIABLE tbPending AS LOGICAL INITIAL no 
     LABEL "All Pending" 
     VIEW-AS TOGGLE-BOX
     &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN SIZE 15 BY .81
     &ELSE SIZE 15 BY .81 &ENDIF NO-UNDO.



/* ************************  Frame Definitions  *********************** */

DEFINE FRAME Select-Frame
     tbSelectAll
          &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN AT ROW 13 COL 2
          &ELSE AT ROW 12.76 COL 2 &ENDIF    
     tbPending
          &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN AT ROW 13 COL 25
          &ELSE AT ROW 12.76 COL 25 &ENDIF
     btnOK
          &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN AT ROW 14 COL 20
          &ELSE AT ROW 13.95 COL 2.8 &ENDIF
     btnCancel
          &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN AT ROW 14 COL 32
          &ELSE AT ROW 13.95 COL 14.4 &ENDIF
     &IF "{&WINDOW-SYSTEM}" NE "TTY" &THEN
       BtnHelp AT ROW 13.95 COL 55.6
     &ENDIF
     RECT-1
          &IF '{&WINDOW-SYSTEM}' = 'TTY':U &THEN AT ROW 15 COL 3
          &ELSE AT ROW 13.71 COL 2 &ENDIF
     SPACE(0.99) SKIP(0.19)
    WITH VIEW-AS DIALOG-BOX KEEP-TAB-ORDER DEFAULT-BUTTON btnOk
         SIDE-LABELS NO-UNDERLINE THREE-D  SCROLLABLE 
         TITLE "Select Change Data Capture Policies for Dump".


/* ***********  Runtime Attributes and AppBuilder Settings  *********** */

ASSIGN FRAME Select-Frame:SCROLLABLE = FALSE
       FRAME Select-Frame:HIDDEN     = TRUE.
                                                                        
IF SESSION:DISPLAY-TYPE = 'TTY':U  THEN 
  RUN CURRENT-WINDOW-layouts (INPUT 'Standard Character':U) NO-ERROR.

/* ************************  Control Triggers  ************************ */

ON GO OF FRAME Select-Frame /* Select Audit Policies for Dump */ DO:
  DEFINE VARIABLE iRow AS INTEGER     NO-UNDO.
  DEFINE VARIABLE i    AS INTEGER     NO-UNDO.  

  IF BROWSE bPolicy:NUM-SELECTED-ROWS = 0 THEN DO:
    MESSAGE "No CDC Policies were selected!" SKIP(1)
            "Please select CDC Policies to dump or select Cancel."
        VIEW-AS ALERT-BOX ERROR BUTTONS OK.
    RETURN NO-APPLY.
  END.
  ELSE DO:     
	  DO i = 1 TO BROWSE bPolicy:NUM-SELECTED-ROWS:
         BROWSE bPolicy:FETCH-SELECTED-ROW(i).
         IF AVAILABLE ttpolicy THEN
            user_env[1] = user_env[1] + (IF user_env[1] NE "" THEN "," ELSE "") +
                          ttPolicy.tcPolName.
      END.
  END.
END.

ON WINDOW-CLOSE OF FRAME Select-Frame /* Select Audit Policies for Dump */ 
  APPLY "END-ERROR":U TO SELF.

ON CHOOSE OF btnCancel IN FRAME Select-Frame /* Cancel */ 
   APPLY "WINDOW-CLOSE" TO FRAME {&FRAME-NAME}.

&IF "{&WINDOW-SYSTEM}" NE "TTY" &THEN

  ON CHOOSE OF BtnHelp IN FRAME Select-Frame /* Help */ OR 
     HELP OF FRAME {&FRAME-NAME} 
    RUN "adecomm/_adehelp.p" ( INPUT "admn", 
                               INPUT "CONTEXT", 
                               INPUT {&Select_Audit_Policies_for_Dump_Dialog_Box},
                               INPUT ? ).
&ENDIF

ON VALUE-CHANGED OF tbSelectAll IN FRAME Select-Frame /* Select All */ DO:
   
  IF SELF:CHECKED THEN
  DO: 
    tbPending:SENSITIVE IN FRAME {&FRAME-NAME} = FALSE.   
    OPEN QUERY qPolicy FOR EACH ttpolicy WHERE ttpolicy.tcPolInstance = "Current" NO-LOCK.
    IF AVAILABLE ttpolicy THEN
	DO:
	    ASSIGN v-rowid = ROWID(ttpolicy).
	    REPOSITION qPolicy TO ROWID v-rowid.
	    BROWSE bPolicy:SELECT-ALL() NO-ERROR.   
	END.    
  END.
  ELSE
  DO:
     tbPending:SENSITIVE IN FRAME {&FRAME-NAME} = TRUE.
     OPEN QUERY qPolicy FOR EACH ttpolicy NO-LOCK.
     BROWSE bPolicy:DESELECT-ROWS() NO-ERROR.
  END.

  FOR EACH ttPolicy WHERE ttpolicy.tcPolInstance = "Current":  
    ttPolicy.tlSelected = SELF:CHECKED.
  END.
END.

ON VALUE-CHANGED OF tbPending IN FRAME Select-Frame /* Select Pending */ DO:
  
  IF SELF:CHECKED THEN
  DO:
    tbSelectAll:SENSITIVE IN FRAME {&FRAME-NAME} = FALSE.
    OPEN QUERY qPolicy FOR EACH ttpolicy WHERE ttpolicy.tcPolInstance = "Pending" NO-LOCK.
    IF AVAILABLE ttpolicy THEN
	DO:
		ASSIGN v-rowid = ROWID(ttpolicy).
	    REPOSITION qPolicy TO ROWID v-rowid.    
	    BROWSE bPolicy:SELECT-ALL() NO-ERROR.    
	END.    
  END.
  ELSE
  DO:
    tbSelectAll:SENSITIVE IN FRAME {&FRAME-NAME} = TRUE.
    OPEN QUERY qPolicy FOR EACH ttpolicy NO-LOCK.
    BROWSE bPolicy:DESELECT-ROWS() NO-ERROR.
  END.

  FOR EACH ttPolicy WHERE ttpolicy.tcPolInstance = "Pending":
    ttPolicy.tlSelected = SELF:CHECKED.
  END.
END.



/* ***************************  Main Block  *************************** */

/* Parent the dialog-box to the ACTIVE-WINDOW, if there is no parent.   */
IF VALID-HANDLE(ACTIVE-WINDOW) AND FRAME {&FRAME-NAME}:PARENT eq ?
THEN FRAME {&FRAME-NAME}:PARENT = ACTIVE-WINDOW.

PAUSE 0 NO-MESSAGE.
lImmedDisp = SESSION:IMMEDIATE-DISPLAY.
SESSION:IMMEDIATE-DISPLAY = TRUE.

DEFINE FRAME {&FRAME-NAME} bPolicy AT COLUMN 2 ROW 2.

DEFINE VARIABLE ccursrc  AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cpolname AS CHARACTER   NO-UNDO.
DEFINE VARIABLE j        AS INTEGER     NO-UNDO.

ON VALUE-CHANGED OF BROWSE bPolicy
DO:
   IF (BROWSE bPolicy:NUM-SELECTED-ROWS > 1) THEN
   DO:
      /* get the policy name and source table of the currently selected row */
      ASSIGN ccursrc  = BROWSE bPolicy:GET-BROWSE-COLUMN(2):SCREEN-VALUE
             cpolname = BROWSE bPolicy:GET-BROWSE-COLUMN(1):SCREEN-VALUE.
       
      /* look through each selected row */
      DO j = 1 TO BROWSE bPolicy:NUM-SELECTED-ROWS:
         BROWSE bPolicy:FETCH-SELECTED-ROW(j).
         
         /* if the source table name of this selected row is the same
          * as the most recently selected row, and the policy name is 
          * not the same, then de-select this selected row. */
         IF (ttPolicy.tctablename = ccursrc) AND (ttPolicy.tcPolName <> cpolname) THEN           
            BROWSE bPolicy:DESELECT-SELECTED-ROW(j).            
      END.
   END.
   RETURN.
END.

ON DEFAULT-ACTION OF BROWSE bPolicy
  APPLY "CHOOSE" TO btnOk IN FRAME {&FRAME-NAME}.

ON CHOOSE OF btnOk IN FRAME {&FRAME-NAME}
  APPLY "GO" TO FRAME {&FRAME-NAME}.

ON END-ERROR OF FRAME {&FRAME-NAME}
  user_env[1] = ?.

/* Now enable the interface and wait for the exit condition.            */
/* (NOTE: handle ERROR and END-KEY so cleanup code will always fire.    */
MAIN-BLOCK:
DO ON ERROR   UNDO MAIN-BLOCK, LEAVE MAIN-BLOCK
   ON END-KEY UNDO MAIN-BLOCK, LEAVE MAIN-BLOCK:
  
  RUN loadPolicies.
  BROWSE bPolicy:MAX-DATA-GUESS = giPolicies.
  IF giPolicies < 1 THEN
  DO:
    tbSelectAll:SENSITIVE IN FRAME {&FRAME-NAME} = FALSE.    
    tbPending:SENSITIVE IN FRAME {&FRAME-NAME}   = FALSE.
  END.

  OPEN QUERY qPolicy FOR EACH ttPolicy.
  ENABLE bPolicy WITH FRAME {&FRAME-NAME}.
  RUN enable_UI.
  APPLY "ENTRY" TO BROWSE bPolicy.
  
  WAIT-FOR GO OF FRAME {&FRAME-NAME}.
END.
SESSION:IMMEDIATE-DISPLAY = lImmedDisp.
RUN disable_UI.

/* **********************  Internal Procedures  *********************** */

PROCEDURE disable_UI :
/*------------------------------------------------------------------------------
  Purpose:     DISABLE the User Interface
  Parameters:  <none>
  Notes:       Here we clean-up the user-interface by deleting
               dynamic widgets we have created and/or hide 
               frames.  This procedure is usually called when
               we are ready to "clean-up" after running.
------------------------------------------------------------------------------*/
  /* Hide all frames. */
  HIDE FRAME Select-Frame.
END PROCEDURE.

PROCEDURE enable_UI :
/*------------------------------------------------------------------------------
  Purpose:     ENABLE the User Interface
  Parameters:  <none>
  Notes:       Here we display/view/enable the widgets in the
               user-interface.  In addition, OPEN all queries
               associated with each FRAME and BROWSE.
               These statements here are based on the "Other 
               Settings" section of the widget Property Sheets.
------------------------------------------------------------------------------*/
  DISPLAY tbSelectAll tbPending
      WITH FRAME Select-Frame.
  ENABLE {&ENABLED-OBJECTS}
         &IF "{&WINDOW-SYSTEM}" NE "TTY" &THEN RECT-1 BtnHelp &ENDIF
      WITH FRAME Select-Frame.
  VIEW FRAME Select-Frame.
END PROCEDURE.

PROCEDURE loadPolicies :
/*------------------------------------------------------------------------------
  Purpose:     Loads ttPolicy Temp-Table with all of the Audit Policy records 
               in the current DICTDB database
  Parameters:  <none>
  Notes:       
------------------------------------------------------------------------------*/
  DEFINE VARIABLE hBuffer AS HANDLE      NO-UNDO.
  DEFINE VARIABLE hQuery  AS HANDLE      NO-UNDO.
  DEFINE VARIABLE hField  AS HANDLE      NO-UNDO.
     
  CREATE BUFFER hBuffer FOR TABLE "DICTDB._Cdc-Table-policy" NO-ERROR.
  CREATE QUERY hQuery.

  hQuery:SET-BUFFERS(hBuffer) NO-ERROR.
  hQuery:QUERY-PREPARE("FOR EACH " + hBuffer:NAME + " NO-LOCK") NO-ERROR.
  hQuery:QUERY-OPEN().

  hBuffer:GET-FIRST() NO-ERROR.
  giPolicies = 0.
  
  DO WHILE NOT hQuery:QUERY-OFF-END TRANSACTION:
    IF hBuffer:AVAILABLE THEN DO:
      giPolicies = giPolicies + 1.
      CREATE ttPolicy.
      ASSIGN hField                   = hBuffer:BUFFER-FIELD("_Policy-Name")
             ttPolicy.tcPolName       = hField:BUFFER-VALUE                   
	         hField                   = hBuffer:BUFFER-FIELD("_Policy-Instance")
	         ttPolicy.tcPolInstance   = If hField:BUFFER-VALUE = "0" then "Current" else if hField:BUFFER-VALUE = "1" then "Previous" else "Pending"
             hField                   = hBuffer:BUFFER-FIELD("_Change-TableName")
             ttPolicy.tcChangeTblName = hField:BUFFER-VALUE.
         
      hField = hBuffer:BUFFER-FIELD("_source-file-recid").
      FIND FIRST _file WHERE RECID(_file) = hField:BUFFER-VALUE NO-LOCK NO-ERROR.
      IF AVAILABLE _file THEN
         ASSIGN ttPolicy.tcTableName   = _file._file-name. 
    END.
    hQuery:GET-NEXT().
  END.

  hQuery:QUERY-CLOSE() NO-ERROR.
  DELETE OBJECT hQuery NO-ERROR.
  DELETE OBJECT hBuffer NO-ERROR.
END PROCEDURE.

PROCEDURE CURRENT-WINDOW-layouts:
  DEFINE INPUT PARAMETER layout AS CHARACTER                     NO-UNDO.
  DEFINE VARIABLE lbl-hndl AS WIDGET-HANDLE                      NO-UNDO.
  DEFINE VARIABLE widg-pos AS DECIMAL                            NO-UNDO.

  /* Copy the name of the active layout into a variable accessible to   */
  /* the rest of this file.                                             */
  CURRENT-WINDOW-layout = layout.

  CASE layout:
    WHEN "Master Layout" THEN DO WITH FRAME {&FRAME-NAME}:
      ASSIGN &IF '{&WINDOW-SYSTEM}' NE 'TTY':U &THEN
               FRAME Select-Frame:HIDDEN      = yes &ENDIF
             FRAME Select-Frame:HEIGHT        = 14.29 + 
                                                FRAME Select-Frame:BORDER-TOP + 
                                                FRAME Select-Frame:BORDER-BOTTOM
             FRAME Select-Frame:WIDTH         = 71.0 + 
                                                FRAME Select-Frame:BORDER-LEFT + 
                                                FRAME Select-Frame:BORDER-RIGHT.

      ASSIGN btnCancel:HIDDEN                 = yes
             btnCancel:COL                    = 14.4
             btnCancel:HEIGHT                 = .95
             btnCancel:ROW                    = 13.95
             btnCancel:HIDDEN                 = no.

      &IF "{&WINDOW-SYSTEM}" NE "TTY" &THEN
        ASSIGN BtnHelp:HIDDEN                 = yes
               BtnHelp:COL                    = 55.6
               BtnHelp:HEIGHT                 = .95
               BtnHelp:ROW                    = 13.95
               BtnHelp:HIDDEN                 = no
               BtnHelp:HIDDEN                 = no.
      &ENDIF
      
      ASSIGN btnOK:HIDDEN                     = yes
             btnOK:COL                        = 2.8
             btnOK:HEIGHT                     = .95
             btnOK:ROW                        = 13.95
             btnOK:HIDDEN                     = no.

      ASSIGN RECT-1:HIDDEN                    = yes
             RECT-1:COL                       = 2
             RECT-1:EDGE-PIXELS               = 2
             RECT-1:HEIGHT                    = 1.38
             RECT-1:ROW                       = 13.71
             RECT-1:WIDTH                     = 65.6
             RECT-1:HIDDEN                    = no
             RECT-1:HIDDEN                    = no.

      ASSIGN tbSelectAll:HIDDEN               = yes
             tbSelectAll:HEIGHT               = .81
             tbSelectAll:ROW                  = 12.76
             tbSelectAll:WIDTH                = 13.4
             tbSelectAll:HIDDEN               = no.      

      ASSIGN tbPending:HIDDEN               = yes
             tbPending:HEIGHT               = .81
             tbPending:ROW                  = 12.76
             tbPending:WIDTH                = 13.4
             tbPending:HIDDEN               = no.

    
      ASSIGN FRAME Select-Frame:VIRTUAL-WIDTH = 71.0
                               WHEN FRAME Select-Frame:SCROLLABLE
             &IF '{&WINDOW-SYSTEM}' NE 'TTY':U &THEN
               FRAME Select-Frame:HIDDEN      = no &ENDIF.

    END.  /* Master Layout Layout Case */

    WHEN "Standard Character":U THEN DO WITH FRAME {&FRAME-NAME}:
      ASSIGN &IF '{&WINDOW-SYSTEM}' NE 'TTY':U &THEN
               FRAME Select-Frame:HIDDEN      = yes &ENDIF
             FRAME Select-Frame:HEIGHT        = 15 + 
                                                FRAME Select-Frame:BORDER-TOP + 
                                                FRAME Select-Frame:BORDER-BOTTOM
             FRAME Select-Frame:WIDTH         = 71 + 
                                                FRAME Select-Frame:BORDER-LEFT + 
                                                FRAME Select-Frame:BORDER-RIGHT
           NO-ERROR.

      ASSIGN btnCancel:HIDDEN                 = yes
             btnCancel:COL                    = 32
             btnCancel:HEIGHT                 = 1
             btnCancel:ROW                    = 14
             btnCancel:HIDDEN                 = no NO-ERROR.

      ASSIGN btnOK:HIDDEN                     = yes
             btnOK:COL                        = 20
             btnOK:HEIGHT                     = 1
             btnOK:ROW                        = 14
             btnOK:HIDDEN                     = no NO-ERROR.

      ASSIGN tbSelectAll:HIDDEN               = yes
             tbSelectAll:HEIGHT               = 1
             tbSelectAll:ROW                  = 13
             tbSelectAll:WIDTH                = 14
             tbSelectAll:HIDDEN               = no NO-ERROR.
     
      ASSIGN tbPending:HIDDEN               = yes
             tbPending:HEIGHT               = 1
             tbPending:ROW                  = 13
             tbPending:WIDTH                = 14
             tbPending:HIDDEN               = no NO-ERROR.



      ASSIGN FRAME Select-Frame:VIRTUAL-WIDTH = 71.00
                    WHEN FRAME Select-Frame:SCROLLABLE
             &IF '{&WINDOW-SYSTEM}' NE 'TTY':U &THEN
               FRAME Select-Frame:HIDDEN      = no &ENDIF NO-ERROR.

    END.  /* Standard Character Layout Case */

  END CASE.
END PROCEDURE.  /* CURRENT-WINDOW-layouts */
&ANALYZE-RESUME


