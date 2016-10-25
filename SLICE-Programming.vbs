#$language = "VBScript"
#$interface = "1.0"

crt.Screen.Synchronous = True
' All configurable options are here
Dim USERNAME, PASSWORD, NPA, HMX, STNSZ, LSRD, DIAL_OUT
USERNAME = "root"
PASSWORD = "yam"
NPA 	 = "312"
HMX 	 = "360"
SEQUENCE = "consecutive"
START    = "1000"
PRI      = True
LSRD	 = True
DIAL_OUT = "99" ' 99 for commercial, 94 for DoD lines

' Not directly editable, but reliant on HMX len
STNSZ    = 7 - Len(HMX)

Dim home_dir, gen_dir, adm_dir
home_dir = "rsh /tmp> "
gen_dir  = "gen> "
adm_dir  = "adm> "

Sub Login()
	crt.Screen.Send chr(13)
	crt.Screen.WaitForString "Login: "
	crt.Screen.Send USERNAME  & chr(13)
	crt.Screen.WaitForString "Password: "
	crt.Screen.Send PASSWORD  & chr(13)
	crt.Screen.WaitForString home_dir
End Sub

Sub Fill_HW()
	' Generate the system and the hardware pls
	crt.Screen.Send "gen" & chr(13)
	crt.Screen.WaitForString gen_dir
	crt.Screen.Send "sys;swi=mil;npa=" + NPA + ";hmx=" + HMX + ";start=" + START + ";seq=" + SEQUENCE + ";spec=y;fill;ex;fill" & chr(13)
	crt.Screen.WaitForString "(Y)es, (N)o, (C)ustomize or (S)witch setting only? "
	crt.Screen.Send "y" & chr(13)
	crt.Screen.WaitForString "How many primary rate circuits for met board in MSU 0/0 slot 1 (0-4)[0]? "
	crt.Screen.Send "4" & chr(13)
	crt.Screen.WaitForString "How many announcer circuits for met board in MSU 0/0 slot 1 (0-8)[0]? "
	crt.Screen.Send "8" & chr(13)

	' We use all the defaults
	crt.Screen.WaitForString "Span type for met circuit 0/0.1/0 (t1,e1,t1_exp)[t1_exp]? "
	crt.Screen.Send chr(13)
	crt.Screen.WaitForString "How many channels for met circuit 0/0.1/0 (0-24)[24]? "
	crt.Screen.Send chr(13)
	crt.Screen.WaitForString "Span type for met circuit 0/0.1/1 (t1,e1,t1_exp)[t1_exp]? "
	crt.Screen.Send chr(13)
	crt.Screen.WaitForString "How many channels for met circuit 0/0.1/1 (0-24)[24]? "
	crt.Screen.Send chr(13)
	crt.Screen.WaitForString gen_dir
	crt.Screen.Send "ac;log" & chr(13)
End Sub

Sub Fix_StnSz()
	If (STNSZ <> 4) Then
		crt.Screen.Send "opt;stnsz=" + CStr(STNSZ) + ";ex;ac" & chr(13)

		' Time for some dank ass DCT shenanigans
		crt.Screen.Send "dct=7;ent=9;" & chr(13)
		crt.Screen.Send "patt=nnx"
		For idx = 1 to (4 - STNSZ)
			crt.Screen.Send "x"
		Next
		crt.Screen.Send ";dct=8;ent=9;patt="
		For idx = 1 to STNSZ
			crt.Screen.Send "x"
		Next
		crt.Screen.Send ";ex;ac;" & chr(13)
	End If
End Sub

' Irrelevant when we use sequenced numbers
Sub Add_POTS()
	crt.Screen.Send "cct=4/0;cir;station=100;cct=4/1;station=200;ex;" & chr(13)
	crt.Screen.WaitForString adm_dir
End Sub

Sub PRI_Trunk()
	' Make the group
	crt.Screen.Send "group;new=trk;group=1;name=" & chr(34) & "PRI to VX" & chr(34) & ";dial=pri;perm;prem;hom;dct=11;side=user;pri_cct=1/10/0;d_chan=1/0/23;mem;add=1/0/0;qty=23;ex;ac;" & chr(13)
	' Clear the circuits
	crt.Screen.Send "cct=1/0/0;signal=clear;cir;fill=all;ex;cct=1/0/23;sig=cl" & chr(13)
	' Build the route
	crt.Screen.Send "ex;route=1;name=" & chr(34) & "PRI to VX" & chr(34) & ";group=1;out=7;del=0;ex;ac" & chr(13)
	' Fix the DCT
	crt.Screen.Send "dct=7;ent=9;type=rte;val=1" & chr(13)
	crt.Screen.Send "ex;ac" & chr(13)
	crt.Screen.WaitForString adm_dir
End Sub

Sub LSRD_Trunk()
	crt.Screen.Send "group;new=trk" & chr(13)
	' TODO: Somehow get the group number of the new group in case we're only doing LSRD and not also PRI
	crt.Screen.Send "group=2;name=LSRD;dial=dtmf;tie;mem;add=10/0/0;qty=2;ex;ac" & chr(13)
	' DCT Shit, yo
	' TODO: Find which DCT entry corresponds to which number
	crt.Screen.Send "dct=3;" & chr(13)
	If (Mid( DIAL_OUT, 2, 1 ) == "9") Then
		' Second dial-out digit is 9
	End If
	If (Mid( DIAL_OUT, 2, 1 ) == "4") Then
		' Second dial-out digit is 4
	End If

	crt.Screen.Send "ex;ac" & chr(13)
	crt.Screen.WaitForString adm_dir
End Sub

Sub Main()
	Login()

	' Reset the SLICE
	crt.Screen.Send "dbunlk" & chr(13)
	crt.Screen.WaitForString "rsh /tmp> "
	crt.Screen.Send "res cl */*" & chr(13)
	crt.Screen.WaitForString "Okay to reboot the shelf? <y/n>"
	crt.Screen.Send "y" & chr(13)
	crt.Screen.WaitForString "Enter confirmation code: "
	crt.Screen.Send "teser" & chr(13)
	crt.Screen.WaitForString " Database changes may be lost, ok to continue? <y/n> "
	crt.Screen.Send "y" & chr(13)

	Login()

	Fill_HW()

	crt.Screen.WaitForString home_dir
	crt.Screen.Send "adm" & chr(13)
	crt.Screen.WaitForString adm_dir

	Fix_StnSz()
	If (SEQUENCE <> "consecutive") Then
		Add_POTS()
	End If

	If (PRI == True) Then
		PRI_Trunk()
	End If

	If (LSRD == True) Then
		LSRD_Trunk()
	End If

End Sub
