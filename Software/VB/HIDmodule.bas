Attribute VB_Name = "Module1"
'Based upon software by Jan Axelson
'http://www.lvr.com/hidpage.htm

Option Explicit

Dim bAlertable As Long
Dim Capabilities As HIDP_CAPS
Dim DataString As String
Dim DetailData As Long
Dim DetailDataBuffer() As Byte
Dim DeviceAttributes As HIDD_ATTRIBUTES
Dim DevicePathName As String
Dim DeviceInfoSet As Long
Dim ErrorString As String
Dim EventObject As Long
Public HIDHandle As Long
Dim HIDOverlapped As OVERLAPPED
Dim LastDevice As Boolean
Public MyDeviceDetected As Boolean
Dim MyDeviceInfoData As SP_DEVINFO_DATA
Dim MyDeviceInterfaceDetailData As SP_DEVICE_INTERFACE_DETAIL_DATA
Dim MyDeviceInterfaceData As SP_DEVICE_INTERFACE_DATA
Dim Needed As Long
Dim PreparsedData As Long
Public ReadHandle As Long
Dim Result As Long
Dim Security As SECURITY_ATTRIBUTES
Public Timeout As Boolean

'Set these to match the values in the device's firmware and INF file.
'0925h is Lakeview Research's vendor ID.

Const MyVendorID = &H3F2
Const MyProductID = &H7CC

Public ReadBuffer() As Byte
Public OutputReportData(31) As Byte

Function FindTheHid() As Boolean
'Makes a series of API calls to locate the desired HID-class device.
'Returns True if the device is detected, False if not detected.

    Dim Count As Integer
    Dim GUIDString As String
    Dim HidGuid As GUID
    Dim MemberIndex As Long

    LastDevice = False
    MyDeviceDetected = False

    'Values for SECURITY_ATTRIBUTES structure:

    Security.lpSecurityDescriptor = 0
    Security.bInheritHandle = True
    Security.nLength = Len(Security)

    '******************************************************************************
    'HidD_GetHidGuid
    'Get the GUID for all system HIDs.
    'Returns: the GUID in HidGuid.
    'The routine doesn't return a value in Result
    'but the routine is declared as a function for consistency with the other API calls.
    '******************************************************************************

    Result = HidD_GetHidGuid(HidGuid)
    Call DisplayResultOfAPICall("GetHidGuid")

    'Display the GUID.

    GUIDString = _
    Hex$(HidGuid.Data1) & "-" & _
                 Hex$(HidGuid.Data2) & "-" & _
                 Hex$(HidGuid.Data3) & "-"

    For Count = 0 To 7

        'Ensure that each of the 8 bytes in the GUID displays two characters.

        If HidGuid.Data4(Count) >= &H10 Then
            GUIDString = GUIDString & Hex$(HidGuid.Data4(Count)) & " "
        Else
            GUIDString = GUIDString & "0" & Hex$(HidGuid.Data4(Count)) & " "
        End If
    Next Count

    'GUID for system HIDs = GUIDString

    '******************************************************************************
    'SetupDiGetClassDevs
    'Returns: a handle to a device information set for all installed devices.
    'Requires: the HidGuid returned in GetHidGuid.
    '******************************************************************************

    DeviceInfoSet = SetupDiGetClassDevs _
                    (HidGuid, _
                     vbNullString, _
                     0, _
                     (DIGCF_PRESENT Or DIGCF_DEVICEINTERFACE))

    Call DisplayResultOfAPICall("SetupDiClassDevs")
    DataString = GetDataString(DeviceInfoSet, 32)

    '******************************************************************************
    'SetupDiEnumDeviceInterfaces
    'On return, MyDeviceInterfaceData contains the handle to a
    'SP_DEVICE_INTERFACE_DATA structure for a detected device.
    'Requires:
    'the DeviceInfoSet returned in SetupDiGetClassDevs.
    'the HidGuid returned in GetHidGuid.
    'An index to specify a device.
    '******************************************************************************

    'Begin with 0 and increment until no more devices are detected.

    MemberIndex = 0

    Do
        'The cbSize element of the MyDeviceInterfaceData structure must be set to
        'the structure's size in bytes. The size is 28 bytes.

        MyDeviceInterfaceData.cbSize = LenB(MyDeviceInterfaceData)
        Result = SetupDiEnumDeviceInterfaces _
                 (DeviceInfoSet, _
                  0, _
                  HidGuid, _
                  MemberIndex, _
                  MyDeviceInterfaceData)

        Call DisplayResultOfAPICall("SetupDiEnumDeviceInterfaces")
        If Result = 0 Then LastDevice = True

        'If a device exists, display the information returned.

        If Result <> 0 Then
            '"  DeviceInfoSet for device #" & CStr(MemberIndex) & ": "
            '"  cbSize = " & CStr(MyDeviceInterfaceData.cbSize)
            '"  InterfaceClassGuid.Data1 = " & Hex$(MyDeviceInterfaceData.InterfaceClassGuid.Data1)
            '"  InterfaceClassGuid.Data2 = " & Hex$(MyDeviceInterfaceData.InterfaceClassGuid.Data2)
            '"  InterfaceClassGuid.Data3 = " & Hex$(MyDeviceInterfaceData.InterfaceClassGuid.Data3)
            '"  Flags = " & Hex$(MyDeviceInterfaceData.Flags)

            '******************************************************************************
            'SetupDiGetDeviceInterfaceDetail
            'Returns: an SP_DEVICE_INTERFACE_DETAIL_DATA structure
            'containing information about a device.
            'To retrieve the information, call this function twice.
            'The first time returns the size of the structure in Needed.
            'The second time returns a pointer to the data in DeviceInfoSet.
            'Requires:
            'A DeviceInfoSet returned by SetupDiGetClassDevs and
            'an SP_DEVICE_INTERFACE_DATA structure returned by SetupDiEnumDeviceInterfaces.
            '*******************************************************************************

            MyDeviceInfoData.cbSize = Len(MyDeviceInfoData)
            Result = SetupDiGetDeviceInterfaceDetail _
                     (DeviceInfoSet, _
                      MyDeviceInterfaceData, _
                      0, _
                      0, _
                      Needed, _
                      0)

            DetailData = Needed

            Call DisplayResultOfAPICall("SetupDiGetDeviceInterfaceDetail")
            '(OK to say too small)
            'Required buffer size for the data = Needed

            'Store the structure's size.

            MyDeviceInterfaceDetailData.cbSize = _
            Len(MyDeviceInterfaceDetailData)

            'Use a byte array to allocate memory for
            'the MyDeviceInterfaceDetailData structure

            ReDim DetailDataBuffer(Needed)

            'Store cbSize in the first four bytes of the array.

            Call RtlMoveMemory _
                 (DetailDataBuffer(0), _
                  MyDeviceInterfaceDetailData, _
                  4)

            'Call SetupDiGetDeviceInterfaceDetail again.
            'This time, pass the address of the first element of DetailDataBuffer
            'and the returned required buffer size in DetailData.

            Result = SetupDiGetDeviceInterfaceDetail _
                     (DeviceInfoSet, _
                      MyDeviceInterfaceData, _
                      VarPtr(DetailDataBuffer(0)), _
                      DetailData, _
                      Needed, _
                      0)

            Call DisplayResultOfAPICall(" Result of second call: ")
            'MyDeviceInterfaceDetailData.cbSize = CStr(MyDeviceInterfaceDetailData.cbSize)

            'Convert the byte array to a string.

            DevicePathName = CStr(DetailDataBuffer())

            'Convert to Unicode.

            DevicePathName = StrConv(DevicePathName, vbUnicode)

            'Strip cbSize (4 bytes) from the beginning.

            DevicePathName = Right$(DevicePathName, Len(DevicePathName) - 4)
            'Device pathname = DevicePathName

            '******************************************************************************
            'CreateFile
            'Returns: a handle that enables reading and writing to the device.
            'Requires:
            'The DevicePathName returned by SetupDiGetDeviceInterfaceDetail.
            '******************************************************************************

            HIDHandle = CreateFile _
                        (DevicePathName, _
                         GENERIC_READ Or GENERIC_WRITE, _
                         (FILE_SHARE_READ Or FILE_SHARE_WRITE), _
                         Security, _
                         OPEN_EXISTING, _
                         0&, _
                         0)

            Call DisplayResultOfAPICall("CreateFile")
            'Returned handle = HIDHandle

            'Now we can find out if it's the device we're looking for.

            '******************************************************************************
            'HidD_GetAttributes
            'Requests information from the device.
            'Requires: The handle returned by CreateFile.
            'Returns: an HIDD_ATTRIBUTES structure containing
            'the Vendor ID, Product ID, and Product Version Number.
            'Use this information to determine if the detected device
            'is the one we're looking for.
            '******************************************************************************

            'Set the Size property to the number of bytes in the structure.

            DeviceAttributes.Size = LenB(DeviceAttributes)
            Result = HidD_GetAttributes _
                     (HIDHandle, _
                      DeviceAttributes)

            Call DisplayResultOfAPICall("HidD_GetAttributes")
            If Result <> 0 Then
                'HIDD_ATTRIBUTES structure filled without error.
            Else
                'Error in filling HIDD_ATTRIBUTES structure.
            End If

            'Structure size = DeviceAttributes.Size
            'Vendor ID = Hex$(DeviceAttributes.VendorID)
            'Product ID = Hex$(DeviceAttributes.ProductID)
            'Version Number = Hex$(DeviceAttributes.VersionNumber)

            'Find out if the device matches the one we're looking for.

            If (DeviceAttributes.VendorID = MyVendorID) And _
               (DeviceAttributes.ProductID = MyProductID) Then

                'It's the desired device.

                'My device detected
                MyDeviceDetected = True
            Else
                MyDeviceDetected = False

                'If it's not the one we want, close its handle.
                Result = CloseHandle _
                         (HIDHandle)
                DisplayResultOfAPICall ("CloseHandle")
            End If
        End If

        'Keep looking until we find the device or there are no more left to examine.

        MemberIndex = MemberIndex + 1
    Loop Until (LastDevice = True) Or (MyDeviceDetected = True)

    'Free the memory reserved for the DeviceInfoSet returned by SetupDiGetClassDevs.

    Result = SetupDiDestroyDeviceInfoList _
             (DeviceInfoSet)
    Call DisplayResultOfAPICall("DestroyDeviceInfoList")

    If MyDeviceDetected = True Then
        FindTheHid = True

        'Learn the capabilities of the device

        Call GetDeviceCapabilities

        'Get another handle for the overlapped ReadFiles.

        ReadHandle = CreateFile _
                     (DevicePathName, _
                      (GENERIC_READ Or GENERIC_WRITE), _
                      (FILE_SHARE_READ Or FILE_SHARE_WRITE), _
                      Security, _
                      OPEN_EXISTING, _
                      FILE_FLAG_OVERLAPPED, _
                      0)

        Call DisplayResultOfAPICall("CreateFile, ReadHandle")
        'Returned handle = ReadHandle
        Call PrepareForOverlappedTransfer
    Else
        'Device not found
    End If
End Function

Private Function GetDataString _
        (Address As Long, _
         Bytes As Long) _
         As String
'Retrieves a string of length Bytes from memory, beginning at Address.
'Adapted from Dan Appleman's "Win32 API Puzzle Book"

    Dim Offset As Integer
    Dim Result$
    Dim ThisByte As Byte

    For Offset = 0 To Bytes - 1
        Call RtlMoveMemory(ByVal VarPtr(ThisByte), ByVal Address + Offset, 1)
        If (ThisByte And &HF0) = 0 Then
            Result$ = Result$ & "0"
        End If
        Result$ = Result$ & Hex$(ThisByte) & " "
    Next Offset

    GetDataString = Result$
End Function

Private Function GetErrorString _
        (ByVal LastError As Long) _
        As String

'Returns the error message for the last error.
'Adapted from Dan Appleman's "Win32 API Puzzle Book"

    Dim Bytes As Long
    Dim ErrorString As String
    ErrorString = String$(129, 0)
    Bytes = FormatMessage _
            (FORMAT_MESSAGE_FROM_SYSTEM, _
             0&, _
             LastError, _
             0, _
             ErrorString$, _
             128, _
             0)

    'Subtract two characters from the message to strip the CR and LF.

    If Bytes > 2 Then
        GetErrorString = Left$(ErrorString, Bytes - 2)
    End If
End Function

Private Sub GetDeviceCapabilities()
'******************************************************************************
'HidD_GetPreparsedData
'Returns: a pointer to a buffer containing information about the device's capabilities.
'Requires: A handle returned by CreateFile.
'There's no need to access the buffer directly,
'but HidP_GetCaps and other API functions require a pointer to the buffer.
'******************************************************************************

    Dim ppData(29) As Byte
    Dim ppDataString As Variant

    'Preparsed Data is a pointer to a routine-allocated buffer.

    Result = HidD_GetPreparsedData _
             (HIDHandle, _
              PreparsedData)
    Call DisplayResultOfAPICall("HidD_GetPreparsedData")

    'Copy the data at PreparsedData into a byte array.

    Result = RtlMoveMemory _
             (ppData(0), _
              PreparsedData, _
              30)
    Call DisplayResultOfAPICall("RtlMoveMemory")

    ppDataString = ppData()

    'Convert the data to Unicode.

    ppDataString = StrConv(ppDataString, vbUnicode)

    '******************************************************************************
    'HidP_GetCaps
    'Find out the device's capabilities.
    'For standard devices such as joysticks, you can find out the specific
    'capabilities of the device.
    'For a custom device, the software will probably know what the device is capable of,
    'so this call only verifies the information.
    'Requires: The pointer to a buffer containing the information.
    'The pointer is returned by HidD_GetPreparsedData.
    'Returns: a Capabilites structure containing the information.
    '******************************************************************************
    Result = HidP_GetCaps _
             (PreparsedData, _
              Capabilities)

    Call DisplayResultOfAPICall("HidP_GetCaps")
    '"  Last error: " & ErrorString
    '"  Usage: " & Hex$(Capabilities.Usage)
    '"  Usage Page: " & Hex$(Capabilities.UsagePage)
    '"  Input Report Byte Length: " & Capabilities.InputReportByteLength
    '"  Output Report Byte Length: " & Capabilities.OutputReportByteLength
    '"  Feature Report Byte Length: " & Capabilities.FeatureReportByteLength
    '"  Number of Link Collection Nodes: " & Capabilities.NumberLinkCollectionNodes
    '"  Number of Input Button Caps: " & Capabilities.NumberInputButtonCaps
    '"  Number of Input Value Caps: " & Capabilities.NumberInputValueCaps
    '"  Number of Input Data Indices: " & Capabilities.NumberInputDataIndices
    '"  Number of Output Button Caps: " & Capabilities.NumberOutputButtonCaps
    '"  Number of Output Value Caps: " & Capabilities.NumberOutputValueCaps
    '"  Number of Output Data Indices: " & Capabilities.NumberOutputDataIndices
    '"  Number of Feature Button Caps: " & Capabilities.NumberFeatureButtonCaps
    '"  Number of Feature Value Caps: " & Capabilities.NumberFeatureValueCaps
    '"  Number of Feature Data Indices: " & Capabilities.NumberFeatureDataIndices

    '******************************************************************************
    'HidP_GetValueCaps
    'Returns a buffer containing an array of HidP_ValueCaps structures.
    'Each structure defines the capabilities of one value.
    'This application doesn't use this data.
    '******************************************************************************

    'This is a guess. The byte array holds the structures.

    Dim ValueCaps(1023) As Byte

    Result = HidP_GetValueCaps _
             (HidP_Input, _
              ValueCaps(0), _
              Capabilities.NumberInputValueCaps, _
              PreparsedData)

    Call DisplayResultOfAPICall("HidP_GetValueCaps")

    'lstResults.AddItem "ValueCaps= " & GetDataString((VarPtr(ValueCaps(0))), 180)
    'To use this data, copy the byte array into an array of structures.

    'Free the buffer reserved by HidD_GetPreparsedData

    Result = HidD_FreePreparsedData _
             (PreparsedData)
    Call DisplayResultOfAPICall("HidD_FreePreparsedData")
End Sub

Private Sub PrepareForOverlappedTransfer()
'******************************************************************************
'CreateEvent
'Creates an event object for the overlapped structure used with ReadFile.
'Requires a security attributes structure or null,
'Manual Reset = True (ResetEvent resets the manual reset object to nonsignaled),
'Initial state = True (signaled),
'and event object name (optional)
'Returns a handle to the event object.
'******************************************************************************

    If EventObject = 0 Then
        EventObject = CreateEvent _
                      (Security, _
                       True, _
                       True, _
                       "")
    End If

    Call DisplayResultOfAPICall("CreateEvent")

    'Set the members of the overlapped structure.

    HIDOverlapped.Offset = 0
    HIDOverlapped.OffsetHigh = 0
    HIDOverlapped.hEvent = EventObject
End Sub

Private Sub DisplayResultOfAPICall(FunctionName As String)
'Display the results of an API call.

    Dim ErrorString As String

    ErrorString = GetErrorString(Err.LastDllError)
    'FunctionName Result = ErrorString
End Sub

Public Sub ReadAndWriteToDevice()
'Sends two bytes to the device and reads two bytes back.

    Dim Count As Integer
    'If the device hasn't been detected or it timed out on a previous attempt
    'to access it, look for the device.

    If MyDeviceDetected = False Then
        MyDeviceDetected = FindTheHid
    End If

    If MyDeviceDetected = True Then
        'Write a report to the device
        Call WriteReport

        'Read a report from the device.
        Call ReadReport
    Else
    End If
End Sub

Public Sub ReadReport()
'Read data from the device.

    Dim Count
    Dim NumberOfBytesRead As Long

    'Allocate a buffer for the report.
    'Byte 0 is the report ID.

    '******************************************************************************
    'ReadFile
    'Returns: the report in ReadBuffer.
    'Requires: a device handle returned by CreateFile
    '(for overlapped I/O, CreateFile must be called with FILE_FLAG_OVERLAPPED),
    'the Input report length in bytes returned by HidP_GetCaps,
    'and an overlapped structure whose hEvent member is set to an event object.
    '******************************************************************************

    Dim ByteValue As String

    'The ReadBuffer array begins at 0, so subtract 1 from the number of bytes.

    ReDim ReadBuffer(Capabilities.InputReportByteLength - 1)

    'Do an overlapped ReadFile.
    'The function returns immediately, even if the data hasn't been received yet.

    Result = ReadFile _
             (ReadHandle, _
              ReadBuffer(0), _
              CLng(Capabilities.InputReportByteLength), _
              NumberOfBytesRead, _
              HIDOverlapped)
    Call DisplayResultOfAPICall("ReadFile")

    'Waiting for ReadFile

    bAlertable = True

    '******************************************************************************
    'WaitForSingleObject
    'Used with overlapped ReadFile.
    'Returns when ReadFile has received the requested amount of data or on timeout.
    'Requires an event object created with CreateEvent
    'and a timeout value in milliseconds.
    '******************************************************************************
    Result = WaitForSingleObject _
             (EventObject, _
              6000)
    Call DisplayResultOfAPICall("WaitForSingleObject")

    'Find out if ReadFile completed or timeout.

    Select Case Result
    Case WAIT_OBJECT_0
        'ReadFile has completed
    Case WAIT_TIMEOUT
        'Timeout

        'Cancel the operation

        '*************************************************************
        'CancelIo
        'Cancels the ReadFile
        'Requires the device handle.
        'Returns non-zero on success.
        '*************************************************************
        Result = CancelIo _
                 (ReadHandle)
        Call DisplayResultOfAPICall("CancelIo")

        'The timeout may have been because the device was removed,
        'so close any open handles and
        'set MyDeviceDetected=False to cause the application to
        'look for the device on the next attempt.

        CloseHandle (HIDHandle)
        Call DisplayResultOfAPICall("CloseHandle (HIDHandle)")
        CloseHandle (ReadHandle)
        Call DisplayResultOfAPICall("CloseHandle (ReadHandle)")
        MyDeviceDetected = False
    Case Else
        'Readfile undefined error
        MyDeviceDetected = False
    End Select

    'Report ID = ReadBuffer(0)
    'Report Data = ReadBuffer(Count)

    '******************************************************************************
    'ResetEvent
    'Sets the event object in the overlapped structure to non-signaled.
    'Requires a handle to the event object.
    'Returns non-zero on success.
    '******************************************************************************

    Call ResetEvent(EventObject)
    Call DisplayResultOfAPICall("ResetEvent")
End Sub

Public Sub WriteReport()
'Send data to the device.

    Dim Count As Integer
    Dim NumberOfBytesWritten As Long
    Dim SendBuffer() As Byte

    'The SendBuffer array begins at 0, so subtract 1 from the number of bytes.

    ReDim SendBuffer(Capabilities.OutputReportByteLength - 1)

    '******************************************************************************
    'WriteFile
    'Sends a report to the device.
    'Returns: success or failure.
    'Requires: the handle returned by CreateFile and
    'The output report byte length returned by HidP_GetCaps
    '******************************************************************************

    'The first byte is the Report ID

    SendBuffer(0) = 0

    'The next bytes are data

    For Count = 1 To Capabilities.OutputReportByteLength - 1
        SendBuffer(Count) = OutputReportData(Count - 1)
    Next Count

    NumberOfBytesWritten = 0

    Result = WriteFile _
             (HIDHandle, _
              SendBuffer(0), _
              CLng(Capabilities.OutputReportByteLength), _
              NumberOfBytesWritten, _
              0)
    Call DisplayResultOfAPICall("WriteFile")

    'OutputReportByteLength = Capabilities.OutputReportByteLength
    'NumberOfBytesWritten = NumberOfBytesWritten
    'Report ID = SendBuffer(0)
    'Report Data = SendBuffer(Count)
End Sub


