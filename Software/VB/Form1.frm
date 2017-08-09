VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "Form1"
   ClientHeight    =   3015
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   4560
   LinkTopic       =   "Form1"
   ScaleHeight     =   3015
   ScaleWidth      =   4560
   StartUpPosition =   3  'Windows Default
   Begin VB.TextBox txtTest 
      Height          =   615
      Left            =   540
      TabIndex        =   1
      Text            =   "txtTest"
      Top             =   180
      Width           =   1875
   End
   Begin VB.CommandButton btnConnect 
      Caption         =   "Connect"
      Height          =   675
      Left            =   1500
      TabIndex        =   0
      Top             =   1200
      Width           =   1575
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Sub btnConnect_Click()
    If Not MyDeviceDetected Then
        MyDeviceDetected = FindTheHid
    End If
    If FindTheHid Then
        txtTest.Text = "True"
    Else
        txtTest = "False"
    End If
End Sub
