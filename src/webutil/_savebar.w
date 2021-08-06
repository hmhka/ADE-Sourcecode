/*E4GL-W*/ {src/web/method/e4gl.i} {&OUT} '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">~n'.
{&OUT} '<!--------------------------------------------------------------------~n'.
{&OUT} '* Copyright (C) 2002 by Progress Software Corporation ("PSC"),       *~n'.
{&OUT} '* 14 Oak Park, Bedford, MA 01730, and other contributors as listed   *~n'.
{&OUT} '* below.  All Rights Reserved.                                       *~n'.
{&OUT} '*                                                                    *~n'.
{&OUT} '* The Initial Developer of the Original Code is PSC.  The Original   *~n'.
{&OUT} '* Code is Progress IDE code released to open source December 1, 2000.*~n'.
{&OUT} '*                                                                    *~n'.
{&OUT} '* The contents of this file are subject to the Possenet Public       *~n'.
{&OUT} '* License Version 1.0 (the "License")~; you may not use this file     *~n'.
{&OUT} '* except in compliance with the License.  A copy of the License is   *~n'.
{&OUT} '* available as of the date of this notice at                         *~n'.
{&OUT} '* http://www.possenet.org/license.html                               *~n'.
{&OUT} '*                                                                    *~n'.
{&OUT} '* Software distributed under the License is distributed on an "AS IS"*~n'.
{&OUT} '* basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. You*~n'.
{&OUT} '* should refer to the License for the specific language governing    *~n'.
{&OUT} '* rights and limitations under the License.                          *~n'.
{&OUT} '*                                                                    *~n'.
{&OUT} '* Contributors:                                                      *~n'.
{&OUT} '*                                                                    *~n'.
{&OUT} '--------------------------------------------------------------------->~n'.
{&OUT} '<HTML>~n'.
{&OUT} '<HEAD>~n'.
{&OUT} '<META NAME="author" CONTENT="Douglas M. Adams">~n'.
{&OUT} '<META NAME="wsoptions" CONTENT="compile">~n'.
{&OUT} '<TITLE>Saving...</TITLE>~n'.

{&OUT} '<STYLE TYPE="text/css">~n'.
{&OUT} '  #bar1 ~{ background:navy ~}~n'.
{&OUT} '  #bar2 ~{ background:white ~}~n'.
{&OUT} '</STYLE>~n'.
{&OUT} '<SCRIPT LANGUAGE="JavaScript1.2" SRC="/webspeed31E/workshop/common.js"><!-- ~n'.
{&OUT} '  document.write("Included common.js file not found.")~; ~n'.
{&OUT} '//--></SCRIPT> ~n'.
{&OUT} '<SCRIPT LANGUAGE="JavaScript1.2"><!--~n'.
{&OUT} '  var iBytesSaved = ' /*Tag=`*/ get-field("bytesSaved") /*Tag=`*/ '~;~n'.
{&OUT} '  var iFileSize   = ' /*Tag=`*/ get-field("fileSize") /*Tag=`*/ '~;~n'.

{&OUT} '  function init() ~{~n'.
{&OUT} '    /*-----------------------------------------------------------------------~n'.
{&OUT} '      Purpose:     Initialization routine.~n'.
{&OUT} '      Parameters:  <none>~n'.
{&OUT} '      Notes:       ~n'.
{&OUT} '    -------------------------------------------------------------------------*/~n'.
{&OUT} '    getBrowser()~;~n'.
{&OUT} '    setScale(iBytesSaved)~;~n'.
{&OUT} '  ~}~n'.

{&OUT} '  function setScale(iBytesSaved) ~{~n'.
{&OUT} '    var iPercent = Math.floor(iBytesSaved / iFileSize * 100)~;~n'.
{&OUT} '    var cPercent = iPercent + " percent"~;~n'.

{&OUT} '    if (isIE4up) ~{~n'.
{&OUT} '      document.all.cValue.innerText      = cPercent~;~n'.
{&OUT} '      document.all.bar1.style.pixelWidth = (iPercent * (380 / 100))~;~n'.
{&OUT} '      document.all.bar2.style.pixelWidth = (380 - document.all.bar1.style.pixelWidth)~;~n'.
{&OUT} '    ~}~n'.
{&OUT} '    else if (isNav4up) ~{~n'.
{&OUT} '      document.cValue.document.write(cPercent)~;~n'.
{&OUT} '      document.cValue.document.close()~;~n'.

{&OUT} '      document.bar1.clip.top    = 25~;~n'.
{&OUT} '      document.bar1.clip.height = 15~;~n'.
{&OUT} '      document.bar1.clip.width  = (iPercent * (380 / 100))~;~n'.

{&OUT} '      document.bar2.clip.top    = 25~;~n'.
{&OUT} '      document.bar2.clip.left   = document.bar1.clip.left + ~n'.
{&OUT} '                                  document.bar1.clip.width~;~n'.
{&OUT} '      document.bar2.clip.height = 15~;~n'.
{&OUT} '      document.bar2.clip.width  = (380 - document.bar1.clip.width)~;~n'.
{&OUT} '    ~}~n'.
{&OUT} '  ~}~n'.
{&OUT} '//--></SCRIPT>~n'.
{&OUT} '</HEAD>~n'.

{&OUT} '<BODY onLoad="setTimeout(''init()'', 1)" BGCOLOR="lightgrey">~n'.

{&OUT} /*Tag=`*/ get-field("fileName") /*Tag=`*/ '<BR>~n'.
{&OUT} 'to ' /*Tag=`*/ get-field("target") /*Tag=`*/ '<BR><BR>~n'.

 /*Tag=<SCRIPT LANGUAGE="SpeedScript">*/ 
  DEFINE VARIABLE isIE AS LOGICAL NO-UNDO.
  IF INDEX(get-cgi('HTTP_USER_AGENT':U), " MSIE ":U) > 0 THEN isIE = TRUE.

  IF isIE THEN
    {&OUT} 
      '<SPAN ID="cValue"></SPAN>':U SKIP
      '<TABLE WIDTH=380 BORDER=1 CELLSPACING=0 CELLPADDING=0>':U SKIP
      '  <TR WIDTH="100%">':U SKIP
      '    <TD ID="bar1" NAME="bar1" HEIGHT=20 WIDTH="0%"></TD>':U SKIP
      '    <TD ID="bar2" NAME="bar2" HEIGHT=20 WIDTH="100%"></TD>':U SKIP
      '  </TR>':U SKIP
      '</TABLE>':U SKIP.
  ELSE
    {&OUT} 
      '<LAYER NAME="cValue"></LAYER>':U SKIP
      '<LAYER NAME="bar1" ROW=50 HEIGHT=20 BGCOLOR="navy"></LAYER>':U SKIP
      '<LAYER NAME="bar2" ROW=50 HEIGHT=20 BGCOLOR="white"></LAYER>':U SKIP.
 /*Tag=</SCRIPT>*/ 

{&OUT} '</BODY>~n'.
{&OUT} '</HTML>~n'.
/************************* END OF HTML *************************/
/*
** File: src/main/abl/webutil/_savebar.w
** Generated on: 2021-03-15 16:17:37
** By: WebSpeed Embedded SpeedScript Preprocessor
** Version: 2
** Source file: src/main/abl/webutil/_savebar.html
** Options: compile,wsoptions-found,web-object
**
** WARNING: DO NOT EDIT THIS FILE.  Make changes to the original
** HTML file and regenerate this file from it.
**
*/
/********************* Internal Definitions ********************/

/* This procedure returns the generation options at runtime.
   It is invoked by src/web/method/e4gl.i included at the start
   of this file. */
PROCEDURE local-e4gl-options :
  DEFINE OUTPUT PARAMETER p_version AS DECIMAL NO-UNDO
    INITIAL 2.0.
  DEFINE OUTPUT PARAMETER p_options AS CHARACTER NO-UNDO
    INITIAL "compile,wsoptions-found,web-object":U.
  DEFINE OUTPUT PARAMETER p_content-type AS CHARACTER NO-UNDO
    INITIAL "text/html":U.
END PROCEDURE.

/* end */
