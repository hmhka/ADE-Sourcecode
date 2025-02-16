/************************************************
Copyright (c) 2013, 2018-2019,2021 by Progress Software Corporation. All rights reserved.
*************************************************/
/** ------------------------------------------------------------------------
    File        : DecisionService
    Purpose     : API for interacting with a Corticon Rules Decision Service 
    Syntax      : 
    Description : 
    @author pjudge
    Created     : Thu Feb 28 15:00:43 EST 2013
    Notes       : * The building of the payload is separated out, since it
                    can be (it's a relatively stateless operation). The processing
                    of the payload is inline, since it interacts with a number of
                    data structures in this class, and it's more efficient to 
                    keep it inline
                  * The processing of the response payload is done via SAX parsing,
                    for performance reasons.
  ---------------------------------------------------------------------- */
routine-level on error undo, throw.

using OpenEdge.BusinessRules.DecisionServiceSelectorEnum.
using OpenEdge.BusinessRules.PayloadBuilder.
using OpenEdge.BusinessRules.RulesServerConnection.
using OpenEdge.BusinessRules.RulesServerConnectionParameters.
using OpenEdge.BusinessRules.SeverityEnum.
using OpenEdge.Core.Assert.
using OpenEdge.Core.ServerConnection.WebServiceConnectionParameters.
using OpenEdge.Core.TimeStamp.
using OpenEdge.Core.XML.SaxReader.
using Progress.Lang.AppError.

class OpenEdge.BusinessRules.DecisionService use-widget-pool:
    
    /* RulesMessage temp-table as a public/shared resouce for callers too */
    {OpenEdge/BusinessRules/ttRulesMessage.i}
    
    /* Schema cache table for mapping message href ID values to app data tables */
    define private temp-table ttTables no-undo
        field TableName       as character
        field XmlNodeName     as character
        field FieldXmlName    as character
        
        index idx1 as primary unique TableName
        index idx2 XmlNodeName.
        
    /* Cross-reference table for storing cross-references between the 
       messages returned from the Decision Service and the payload. */
    define private temp-table ttXref no-undo
        field HrefId as character
        field TargetBuffer as handle
        field TargetRowid as rowid
        
        index idx1 as primary unique HrefId.
        
    /* (Mandatory). The name of the decision service to invoke. */
    define public property Name as character no-undo get. private set.
    
    /* (optional) The version of the decision service to invoke.
       
       Defaults to unknown value, which is the latest/most recent version. Only 
       one of Version or EffectiveOn can be used at a time; the choice of which
       is made by the developer when calling the constructor. */
    define public property Version as decimal no-undo get. private set.
    
    /* (optional) The effective date with which which to select the decision 
       service to invoke.
       
       Defaults to unknown value, which is the latest/most recent version. Only 
       one of Version or EffectiveOn can be used at a time; the choice of which
       is made by the developer when calling the constructor. */
    define public property EffectiveOn as datetime-tz no-undo get. private set.
    
    /* (mandatory) The Server connection object representing the physical server 
       on which this decision service will be run/invoked. */
    define protected property ServerConnection as RulesServerConnection no-undo get. private set.
    
    define private variable moPayloadBuilder as PayloadBuilder no-undo.
    define private variable moDecisionServiceSelector as DecisionServiceSelectorEnum no-undo.
    
    define private variable moSaxReader as SaxReader no-undo.    
    
    /* SAX-READER require us to use all of these stateful variables. */
    define private variable mhAppData as handle no-undo.
    define private variable mhDataBuffer as handle no-undo.
    define private variable mhBufferField as handle no-undo.
    define private variable mcCurrentFieldValue as longchar no-undo.
    
    /* Details shown by the private constructor doc. */
    constructor public DecisionService(input poServer as RulesServerConnection,
                                       input pcDecisionServiceName as character,
                                       input pdVersion as decimal):
        this-object(poServer, pcDecisionServiceName, pdVersion, ?).
    end method.
    
    /* Details shown by the private constructor  doc. */
    constructor public DecisionService(input poServer as RulesServerConnection,
                                       input pcDecisionServiceName as character):
        this-object(poServer, pcDecisionServiceName, ?, ?).
    end method.
    
    /* Details shown by the private constructor  doc. */
    constructor public DecisionService(input poServer as RulesServerConnection,
                                       input pcDecisionServiceName as character,
                                       input ptEffectiveOn as datetime-tz):
        this-object(poServer, pcDecisionServiceName, ?, ptEffectiveOn).
    end method.
    
    destructor DecisionService():
        DestroyComponent().
    end destructor.
    
    /** Private constructor for this class. Used instead of a real constructor 
        since some transformations have to happen before its called, and since
        a constructor must be invoked first via SUPER or THIS-OBJECT, there's 
        no room for those transformations. 
        
        @param RulesServerConnection (mandatory) The server connection to use
        @param character (mandatory) The name of the decision service
        @param decimal The version of the decision service to use.
        @param datetime-tz The effective date with which which to select the 
                           decision service to use.  */
    constructor private DecisionService(input poServer as RulesServerConnection,
                                        input pcDecisionServiceName as character,
                                        input pdVersion as decimal,
                                        input ptEffectiveOn as datetime-tz):
        Assert:NotNull(poServer, 'Server Connection').
        Assert:NotNullOrEmpty(pcDecisionServiceName, 'Decision Service Name').
        
        /* Must specify either version OR date OR neither */
        if pdVersion ne ? and ptEffectiveOn ne ? then
            undo, throw new AppError(
                    substitute('Decision Service versions can be selected by either version number or date or neither, but not both')
                    , 0).
        
        if pdVersion ne ? then
            Assert:IsZeroOrPositive(pdVersion, 'Decision Service Version').
        
        assign this-object:ServerConnection = poServer
               this-object:Name = pcDecisionServiceName
               this-object:Version = pdVersion
               this-object:EffectiveOn = ptEffectiveOn.
        
        if pdVersion ne ? then        
            this-object:moDecisionServiceSelector = DecisionServiceSelectorEnum:Version.
        else
        if ptEffectiveOn ne ? then
            this-object:moDecisionServiceSelector = DecisionServiceSelectorEnum:Date.
        else
            this-object:moDecisionServiceSelector = DecisionServiceSelectorEnum:Default.
            
        Initialise().
    end method.
    
    method protected void DestroyComponent():
        empty temp-table ttTables.
        empty temp-table RulesMessage.
        
        moSaxReader:SaxReaderCharacters:Unsubscribe(this-object:SaxReaderCharactersHandler).        
        moSaxReader:SaxReaderStartElement:Unsubscribe(this-object:SaxReaderStartElementHandler).
        moSaxReader:SaxReaderEndElement:Unsubscribe(this-object:SaxReaderEndElementHandler).
    end method.
    
    method protected void Initialise():
        define variable oAppError as AppError no-undo.
        define variable cSub2 as character no-undo.
        
        moPayloadBuilder = new PayloadBuilder().
        
        /* Read SOAP response */
        moSaxReader = new SaxReader().
        
        moSaxReader:SaxReaderCharacters:Subscribe(this-object:SaxReaderCharactersHandler).
        moSaxReader:SaxReaderStartElement:Subscribe(this-object:SaxReaderStartElementHandler).
        moSaxReader:SaxReaderEndElement:Subscribe(this-object:SaxReaderEndElementHandler).       
    end method.
    
    /** Returns true if the current Decision Service is deployed.
        
        @return logical Whether the decision service is deployed of not. */    
    method public logical IsServiceAvailable():
        /* The Admin service via SOAP which is being utilized by ABL is no longer in Corticon 6.0. 
           So, stopping the ABL Rules API from making that call on the Admin API*/
        return true.
    end method.
    
    /** Invokes the decision service with the passed-in payload. Accepts a table 
        handle for passing to the decision service. Expected usage is that this 
        method be called BY-REFERENCE for a shallow copy. The results of the 
        decision service call are returned in the output parameter, and the 
        input data is not updated at all. The temp-table passed into this method 
        can not be part of a ProDataSet (an AppError is thrown if it is). 
        
        The output table is a clone of the input table - the intent of this API 
        is to allow callers to use the input data as a before-image for comparison 
        purposes. References in the RulesMessage table returned by the 
        GetMessages() call are to the response table (important if the reference 
        key is a ROWID).
        
        @param table-handle The business data to pass to the decision service.
        @param output table-handle The result/response data of the decision 
                                   service. */
    method public void InvokeService(input  table-handle phAppData,
                                     output table-handle phResponseData):
        define variable hAppDataset as handle no-undo.
        define variable hResponseDataset as handle no-undo.
        
        Assert:NotNull(phAppData, 'Temp-Table').
        Assert:IsNull(phAppData:default-buffer-handle:dataset, 
                    substitute ('Temp-table &1~'s dataset handle', phAppData:name)).
        
        /* Create a temporary dataset to hold the input temp-table.
           datasets let us use more sophisticated structures for 
           data comparisons etc */
        create dataset hAppDataset.
        hAppDataset:name = 'TempDataset'.
        hAppDataset:add-buffer(phAppData:default-buffer-handle).
        
        /* Set the Auto-Delete to False since we're re-using the input buffer
           and we don't want those to get blown away willy-nilly when the cloned 
           dataset is cleaned up.
           
           We MUST do this /after/ the buffer's been added to the ProDataSet else
           it has no effect. */
        phAppData:default-buffer-handle:auto-delete = false.
        
        create temp-table phResponseData.
        phResponseData:create-like(phAppData).
        
        InvokeService(input  dataset-handle hAppDataset by-reference,
                      output dataset-handle hResponseDataset by-reference).
        phResponseData:copy-temp-table(hResponseDataset:get-buffer-handle(1):table-handle).
        
        finally:
            /* done with temporary datasets */
            delete object hAppDataset no-error.
            delete object hResponseDataset no-error.
        end finally.                                         
    end method.
    
    /** Invokes the decision service with the passed-in payload. Accepts a table 
        handle for passing to the decision service. Expected usage is that this 
        method be called BY-REFERENCE for a shallow copy. The contents of this 
        temp-table are removed and replaced by the results of the decision 
        service call. The temp-table passed into this method can not be part of 
        a ProDataSet (an AppError is thrown if it is)
            
        @param input-output table-handle The business data passed to and from the 
                                         decision service. */
    method public void InvokeService(input-output table-handle phAppData):
        define variable hTempDataset as handle no-undo.
        
        Assert:NotNull(phAppData, 'Temp-Table').
        Assert:IsNull(phAppData:default-buffer-handle:dataset, 
                    substitute ('Temp-table &1~'s dataset handle', phAppData:name)).
        
        /* create a temporary dataset to hold the input temp-table.
           datasets let us use more sophisticated structures for 
           data comparisons etc */
        create dataset hTempDataset.
        hTempDataset:name = 'TempDataset'.
        hTempDataset:add-buffer(phAppData:default-buffer-handle).
        
        /* Set the Auto-Delete to False since we're re-using the input buffer
           and we don't want those to get blown away willy-nilly when the cloned 
           dataset is cleaned up.
            
           We MUST do this /after/ the buffer's been added to the ProDataSet else
           it has no effect. */
        phAppData:default-buffer-handle:auto-delete = false.
        
        InvokeService(input-output dataset-handle hTempDataset by-reference).
        
        finally:
            /* done with temporary dataset */        
            delete object hTempDataset no-error.
        end finally.
    end method.

    /** Invokes the decision service with the passed-in payload. Accepts a
        ProDataSet handle for passing to the decision service. Expected usage is 
        that this method be called BY-REFERENCE for a shallow copy. The results 
        of the decision service call are returned in the output parameter, and 
        the input data is not updated at all.  
        
        The output dataset is a clone of the input dataset - the intent of this 
        API is to allow callers to use the input data as a before-image for 
        comparison purposes. References in the RulesMessage table returned by 
        the GetMessages() call are to tables in the response ProDataSet 
        (important if the reference key is a ROWID).  
    
        @param dataset-handle Dataset containing the input business data for 
                              processing by the decision service
        @param output dataset-handle Dataset containing the return/response business
                                     data from the decision service.  */
    method public void InvokeService(input  dataset-handle phAppData,
                                     output dataset-handle phResponseData):
        Assert:NotNull(phAppData, 'ProDataSet').
        
        create dataset phResponseData.
        
        /* make sure the schema matches reasonably well. */
        phResponseData:create-like(phAppData).

        InvokeService(input dataset-handle phAppData by-reference,
                      input dataset-handle phResponseData by-reference).
    end method.
    
    /** Invokes the decision service with the passed-in payload. Accepts a 
        ProDataSet handle for passing to the decision service. Expected 
        usage is that this method be called BY-REFERENCE for a shallow copy. The 
        contents of this ProDataSert are removed and replaced by the results of 
        the decision service call
        
        @param input-output dataset-handle Dataset containing the business data
                                           for processing by the decision service. */
    method public void InvokeService(input-output dataset-handle phAppData):
        Assert:NotNull(phAppData, 'ProDataSet').
        
        InvokeService(input dataset-handle phAppData by-reference,
                      input dataset-handle phAppData by-reference).
    end method.

    /** Protected 'worker' method that performs the service call.
        This method must be called BY-REFERENCE for performance reasons. The params
        are defined as DATASET-HANDLE for clarity/readability; they could just
        as easily be HANDLEs. 
        
        @param dataset-handle Dataset containing the business applications data
        @param dataset-handle (Empty) Dataset for the service response data */
    method protected void InvokeService(input dataset-handle phAppData,
                                        input dataset-handle phResponseData ):
        define variable lcResponseData as longchar no-undo.
        define variable requestData as longchar no-undo.
        define variable cSelectorValue as character no-undo.
        
        Assert:NotNull(phAppData, 'Application Data container').
        Assert:NotNull(phResponseData, 'Temporary Data container').
        
        /* Cache of temp-table data */
        CacheAppDataSchema(phAppData).
        
        /* Calling the InvokeService API means that the caller is ready for another
           service call and is done with the existing rules messages. Get rid of 'em */
        empty temp-table RulesMessage.
        
        /* clean out our internal xref table */
        empty temp-table ttXref.
        
        /* Create Decison Service payload XML and invoke the service */
        case moDecisionServiceSelector:
            when DecisionServiceSelectorEnum:Default then cSelectorValue = ?.
            when DecisionServiceSelectorEnum:Version then cSelectorValue = string(this-object:Version).
            when DecisionServiceSelectorEnum:Date    then cSelectorValue = iso-date(this-object:EffectiveOn).
        end case.
        
        /* Do the work */
        assign requestData = moPayloadBuilder:BuildPayload(
                                    this-object:Name,
                                    moDecisionServiceSelector,
                                    cSelectorValue,
                                    phAppData).
        
        // ADAS7228: "Somewhat" hacky fix for the Corticon 5.7+ WSDL
        // The invoke message input part changed names 
        // FROM 
        //   <wsdl:message name="executeRequest">
        //      <wsdl:part element="tns1:execute" name="part" />
        //   </wsdl:message>
        // TO
        //  <wsdl:message name="invoke">
        //      <wsdl:part element="ns1:CorticonRequest" name="CorticonRequest">
        //      </wsdl:part>
        //  </wsdl:message>
        // The SOAP-OUT functionality requires that the top-level element of the input XML doc and the
        // message part name match.
        // The message created by the PayloadBuilder has a top-level element of <CorticonRequest>; for earlier 
        // versions of the WSDL it needs to add a top-level <execute> element
        if cast(cast(this-object:ServerConnection:ConnectionParameters, RulesServerConnectionParameters)
                :DecisionServiceConnectionParameters, WebServiceConnectionParameters):PortName eq 'CcServerMessagingAxis':u 
        then
            assign requestData = '<execute>':u + requestData + '</execute>':u
                   // Because of the changed SOAP stack in Corticon 5.7 we need to muck about with the namespace for nils
                   // Prior to 5.7 we can use xsi:nil
                   requestData = replace(requestData, 'abl:nil':u, 'xsi:nil':u)
                   .
        
        lcResponseData = this-object:ServerConnection:InvokeDecisionService(requestData).
        /* Convert XML response into application data and (linked) Rule Messages */
        LoadResponseDocument(lcResponseData, dataset-handle phResponseData by-reference).
    end method.
    
    /** Caches the schema of the input data structure for mapping response
        data to the input data.
        
        @param handle The input dataset */
    method protected void CacheAppDataSchema(input phAppData as handle):
        define variable iLoop as integer no-undo.
        define variable hBuffer as handle no-undo.
        define variable iMax as integer no-undo.
        define variable iLoop2 as integer no-undo.
        define variable iMax2 as integer no-undo.
        define variable cDelim as character no-undo.
        
        assign iMax = phAppData:num-buffers.        
        do iloop = 1 to iMax:
            hBuffer = phAppData:get-buffer-handle(iLoop).
            
            find ttTables where ttTables.TableName eq hBuffer:name no-error.
            if not available ttTables then
            do:
                create ttTables.
                assign ttTables.TableName = hBuffer:name
                       ttTables.XmlNodeName = hBuffer:xml-node-name
                       
                       iMax2 = hBuffer:num-fields
                       cDelim = ''.
                
                do iLoop2 = 1 to iMax2:
                    assign ttTables.FieldXmlName = ttTables.FieldXmlName
                                                 + cDelim
                                                 + hBuffer:buffer-field(iLoop2):xml-node-name
                           cDelim = ','.
                end.    /* field loop */
            end. /* n/a ttTables */
        end.    /* buffer loop */
    end method.
    
    /** Convert XML response into application data and (linked) Rule Messages 
        
        @param longchar An XML document containing the service response
        @param dataset-handle The dataset into which to load the data from the
                              response document. */
    method protected void LoadResponseDocument(input pcResponseDocument as longchar,
                                               input dataset-handle phResponseData):
        define variable loop as integer no-undo.
        define variable cnt as integer no-undo.
        define variable trackChanges as logical extent no-undo.
        define variable tbl as handle no-undo.
        
        /** DATA **/
        assign mhAppData            = phResponseData:handle
               cnt                  = phResponseData:num-buffers
               extent(trackChanges) = cnt
               .
        // reset tracking changes
        do loop = 1 to cnt:
            assign tbl                  = phResponseData:get-buffer-handle(loop):table-handle
                   trackChanges[loop]   = tbl:tracking-changes
                   tbl:tracking-changes = false
                   .
        end.
        
        /* Emplicitly empty the dataset, since the this may be the same dataset as 
           the AppData. In that case, it will contain the input data. We want to 
           replace it with the response data.
           
           In addition, the EMPTY is necessary because the decision service is
           capable of deleting records. */
        phResponseData:empty-dataset().
        
        /* Ready? Go! */
        moSaxReader:ParseDocument(pcResponseDocument).
        
        // reset tracking changes
        do loop = 1 to cnt:
            assign phResponseData:get-buffer-handle(loop):table-handle:tracking-changes = trackChanges[loop].
        end.
    end method.
    
    /** Returns the messages for the most recent decision service invocation. 
        Idempotent - a repeated call to this method will always return the same 
        data. The message data is only cleared when a new InvokeService call is
        made. References in the RulesMessage table are to the response data 
        structure used in the InvokeService()} call, which may differ from the 
        input application data data structure. See the InvokeService 
        documentation for details. 
        
        @param output table The RulesMessage table as defined in 
                            {OpenEdge/BusinessRules/ttRulesMessage.i} */
    method public void GetMessages(output table RulesMessage):
        /* nothing needed here */
    end method.
    
    /** CHARACTERS event handler for the SAX-READER. Method implemented as per 
        ABL documentation.  */
    method void SaxReaderCharactersHandler(input phSaxReader as handle,
                                           input pcCharData as longchar,
                                           input piNumChars as integer):
        /* There are a few cases where we don't want to collect the characters
           data in this handler. See the SaxReaderStartElementHandler for more. */
        if valid-handle(mhBufferField) then
            assign mcCurrentFieldValue = mcCurrentFieldValue + pcCharData.
    end method.
    
    /** START-ELEMENT event handler for the SAX-READER. Method implemented as per 
        ABL documentation.  */
    method void SaxReaderStartElementHandler(input phSaxReader    as handle,
                                             input pcNamespaceURI as character,
                                             input pcLocalName    as character,
                                             input pcQName        as character,
                                             input phAttributes   as handle):
        define variable iIdx as integer no-undo.
        define variable iLoop as integer no-undo.
        define variable iMax as integer no-undo.
        define variable cValue as character no-undo.
        define variable lIsBufferNode as logical no-undo.
        define variable cBufferAttributeName as character no-undo.
        
        define buffer lbMessage for RulesMessage.
        
        case pcLocalName:
            when 'Messages' then
            do:
                /* Create a row for the Message header information. This is
                   extraneous for decision services that have had the version
                   number specified, but if a date of a default/unknown value
                   is used for the version, this is useful information. */
                create lbMessage.
                assign lbMessage.Severity = SeverityEnum:Info:ToString()
                       lbMessage.MessageText = 
                            substitute('Version &2 of Decision Service &1 was invoked',
                                    quoter(this-object:Name),
                                    phAttributes:get-value-by-qname('version')) 
                       lbMessage.TableName = ?
                       lbMessage.DataKeyField = ?
                       lbMessage.DataKeyValue = ?.
            end.    /* Messages (plural) */
            when 'Message' then
                create RulesMessage.
            /* Boilerplate */
            when 'execute' or when 'CorticonResponse' or when 'WorkDocuments' then
                /* NO-OP : do this to avoid trying to find buffer handles */ .
            otherwise
            do:
                /* If we're reading message data, write it to the RulesMessages
                   temp-table. The SaxReaderEndElementHandler handler will do the
                   actual writing of the data. */
                if available RulesMessage then
                case pcLocalName:
                    when 'severity' then
                        assign mcCurrentFieldValue = ''
                               mhBufferField = buffer RulesMessage:buffer-field('Severity').
                    when 'text' then
                        assign mcCurrentFieldValue = ''
                               mhBufferField = buffer RulesMessage:buffer-field('MessageText').
                    when 'entityReference' then
                    do:
                        mhBufferField = ?.
                        SetDataKeyValue(phAttributes:get-value-by-qname('href')).
                    end.
                    otherwise
                        assign mcCurrentFieldValue = ?
                               mhBufferField = ?.
                end case.
                else
                do:
                    if valid-handle(phAttributes) and phAttributes:num-items gt 0 then
                    do:
                        /* If there's a 'tt' or 'xsi:type' attribute, then this 
                           is a buffer. PayloadBuilder wrote the 'tt' attribute,
                           the decision service writes the xsi:type attribute for
                           records it creates.
                           
                           Child records are always written last (after any fields
                           for a buffer). */
                        cBufferAttributeName = 'tt'.
                        if phAttributes:get-index-by-qname(cBufferAttributeName) eq ? then
                            cBufferAttributeName = 'xsi:type'.
                        
                        assign iIdx          = phAttributes:get-index-by-qname(cBufferAttributeName)
                               lIsBufferNode = (iIdx gt 0 and iIdx ne ?).
                        if lIsBufferNode then
                            CreateOrFindRecord(phAttributes:get-value-by-qname(cBufferAttributeName),
                                               phAttributes:get-value-by-qname('id') ).
                    end.
                    else
                        assign lIsBufferNode = false.
                    
                    /* Find the field name that maps to the element. */
                    if not lIsBufferNode and valid-handle(mhDataBuffer) and mhDataBuffer:available then
                    do:
                        /* ttTables was found when we created the record */
                        assign iIdx          = lookup(pcLocalName, ttTables.FieldXmlName)
                               mhBufferField = ?.
                        /* make sure the element exists as a field in the temp-table */
                        if iIdx gt 0 then
                            assign mhBufferField = mhDataBuffer:buffer-field(iIdx)
                                   mcCurrentFieldValue = ''.
                    end.
                    else
                        assign mhBufferField = ?
                               mcCurrentFieldValue = ?.
                end.
                
                if not lIsBufferNode and valid-handle(phAttributes) then
                do:
                    // the SOAP changes in Corticon 5.7 removed the xsi namespace from the response
                    assign iIdx = phAttributes:get-index-by-qname('nil':u).
                    if iIdx eq ? then
                        assign iIdx = phAttributes:get-index-by-qname('xsi:nil':u).
                    
                    /* is this a unknown/nil value? */
                    if     not iIdx eq ? 
                       and logical(phAttributes:get-value-by-index(iIdx))
                       and valid-handle(mhBufferField) 
                    then
                        assign mhBufferField:buffer-value = ?
                               mcCurrentFieldValue        = ?
                               mhBufferField              = ?.
                end.    /* has attributes */
            end.    /* not boilerplate node */
        end case.
    end method.
    
    method private void CreateOrFindRecord(input pcBufferName as character,
                                           input pcHrefId as character):
        /* release the previous one */
        if valid-handle(mhDataBuffer) and mhDataBuffer:available then
            mhDataBuffer:buffer-release().
        
        /* This method will only execute if we have a new buffer/entity.
           In this case, we want to unset the buffer and field holders */        
        assign mhBufferField = ?
               mhDataBuffer  = ?.
               
        /* We look in the meta-data temp-table for the existence of a
           buffer. The buffer name may be a "tt" attribute value or a 
           "xsi:type" value. The former is exactly a table name, written 
           by us when creating the payload; the latter is an identifier
           added by the Decision Service for elements that it creates (ie
           new rows).
           
           Alas, XML-NODE-NAMEs are not unique within a dataset and 
           so we simply pick the first one we find. */
        find ttTables where ttTables.TableName eq pcBufferName no-error.
        if not available ttTables then
           find first ttTables where ttTables.XmlNodeName eq pcBufferName no-error.
        if available ttTables then
            assign mhDataBuffer = mhAppData:get-buffer-handle(ttTables.TableName).
        
        if valid-handle(mhDataBuffer) then
        do:
            /* we may have multiple nodes representing the record.
               if so, last value in wins. */
            find ttXref where ttXref.HrefId eq pcHrefId no-error.
            
            if available ttXref then
                mhDataBuffer:find-by-rowid(ttXref.TargetRowid).
            else
            do:
                mhDataBuffer:buffer-create().
                
                create ttXref.
                assign ttXref.HrefId = pcHrefId
                       ttXref.TargetBuffer = mhDataBuffer
                       ttXref.TargetRowid = mhDataBuffer:rowid.
            end.
        end.
        else
            /* make sure there's nothing available */
            find ttTables where rowid(ttTables) eq ? no-error.
    end method.
    
    /** END-ELEMENT event handler for the SAX-READER. Method implemented as per 
        ABL documentation.  */
    method public void SaxReaderEndElementHandler(input phSaxReader as handle,
                                                  input pcNamespaceURI as character,
                                                  input pcLocalName as character,
                                                  input pcQName as character):
        case pcLocalName:
            /* Boilerplate, nothing doing here. */
            when 'CorticonResponse' or when 'execute' or when 'WorkDocuments' 
              or when 'Messages' or when 'Message' then
                /* NO-OP : do this to avoid trying to find buffer handles */ .
            otherwise
            /* this should only contain closing elements for Buffers/Tables,
               Messages and their contained fields. */
            do:
                /* release when it's the end of the table node */
                if valid-handle(mhDataBuffer) and 
                   pcLocalName eq ttTables.XmlNodeName then
                    mhDataBuffer:buffer-release(). 
                else
                if valid-handle(mhBufferField) and mcCurrentFieldValue ne ? and 
                   /* The RulesMessage temp-table does not use XML-NODE-NAME
                      for mapping field names; we have to workaround that. 
                      
                      These 2 conditions could be split, but I am trying to keep
                      the buffer value assignment CASE statement inline and un-
                      duplicated. */
                   (pcLocalName eq mhBufferField:xml-node-name or
                    available RulesMessage) then
                case mhBufferField:data-type:
                    when 'decimal' then
                        mhBufferField:buffer-value = decimal(replace(mcCurrentFieldValue, '.', session:numeric-decimal-point)).
                    when 'integer' then
                        mhBufferField:buffer-value = integer(mcCurrentFieldValue).
                    when 'int64' then
                        mhBufferField:buffer-value = int64(mcCurrentFieldValue).
                    when 'logical' then
                        mhBufferField:buffer-value = logical(mcCurrentFieldValue).
                    when 'date' then 
                        /* Corticon Server maintains the date format masks that 
                           are passed into the Decision Service. In PayloadBuilder 
                           we hard-code the format to YYYY-MM-DD so that's what 
                           we're expecting in return. */
                        mhBufferField:buffer-value = date(
                                integer(entry(2, mcCurrentFieldValue, '-')),
                                integer(entry(3, mcCurrentFieldValue, '-')),
                                integer(entry(1, mcCurrentFieldValue, '-'))).
                    when 'datetime' then
                        mhBufferField:buffer-value = TimeStamp:ToABLDateTimeFromISO(string(mcCurrentFieldValue)).
                    when 'datetime-tz' then
                        mhBufferField:buffer-value = TimeStamp:ToABLDateTimeTzFromISO(string(mcCurrentFieldValue)).
                    when 'character' then 
                        mhBufferField:buffer-value = string(mcCurrentFieldValue).
                    when 'clob' then
                        mhBufferField:buffer-value = mcCurrentFieldValue. 
                    when 'blob' or when 'raw' or when 'rowid' then
                        mhBufferField:buffer-value = base64-decode(mcCurrentFieldValue).
                end case.   /* datatype */
            end.    /* end of field node/element */
        end case.
    end method.
    
    /** Updates the DataKeyValue and TableName fields in the RulesMessage buffer
        from the application data.
        
        @param character The value of the return messages' entityReference href 
                         attribute, which contains the link to the application
                         data */
    method private void SetDataKeyValue(input pcMessageEntityHref as character):
        define variable cKey as character no-undo.
        define variable cTableName as character no-undo.
        define variable cDataKeyField as character no-undo.
                                                
        /* Strip off the leading hash.
           defaults in case we cannot determine the table */
        assign cKey = substring(pcMessageEntityHref, 2)
               cTableName = ?
               cDataKeyField = ?.
        
        find ttXref where ttXref.HrefId eq cKey no-error.
        if available ttXref then
            assign cTableName    = ttXref.TargetBuffer:name
                   cDataKeyField = 'rowid'
                   cKey          = string(ttXref.TargetRowid).

        assign RulesMessage.TableName = cTableName
               RulesMessage.DataKeyField = cDataKeyField
               RulesMessage.DataKeyValue = cKey.
    end method.
    
end class.