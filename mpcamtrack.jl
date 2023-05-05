@everywhere using Blink, Elveflow, Distributed, SharedArrays, Printf

@everywhere function myguifunc(myflags,myreadpressure,mysetpressure)
    w = Window()
    #load!(w,"mpcamtrack.html")
    title(w,"Julia mpcamtrack")
    f=open("mpcamtrack.html") do file
        read(file,String)
    end
    #body!(w,f, async=false)
    loadhtml(w,f)
    while active(w)
        pressurestringholder=Printf.format.(Ref(Printf.Format("%.2f")),myreadpressure)
        js(w, Blink.JSString("""document.getElementById("lp1").innerHTML="$(pressurestringholder[1])" """))
        js(w, Blink.JSString("""document.getElementById("lp2").innerHTML="$(pressurestringholder[2])" """))
        js(w, Blink.JSString("""document.getElementById("lp3").innerHTML="$(pressurestringholder[3])" """))
        js(w, Blink.JSString("""document.getElementById("lp4").innerHTML="$(pressurestringholder[4])" """))
        js(w, Blink.JSString("""document.getElementById("rp1").innerHTML="$(pressurestringholder[5])" """))
        js(w, Blink.JSString("""document.getElementById("rp2").innerHTML="$(pressurestringholder[6])" """))
        js(w, Blink.JSString("""document.getElementById("rp3").innerHTML="$(pressurestringholder[7])" """))
        js(w, Blink.JSString("""document.getElementById("rp4").innerHTML="$(pressurestringholder[8])" """))
        mysetpressure[1]=parse(Float64,js(w, Blink.JSString("""document.getElementById("lpb1am").innertext""")))
        sleep(0.01)
    end
    myflags[1]=0
end

@everywhere function myelveflowfunc(myflags,myreadpressure,mysetpressure)
    Instr_ID=Ref{Int32}(0)
    Instr_ID2=Ref{Int32}(1)
    error=OB1_Initialization("01CB2A4A",4,4,4,4,Instr_ID)
    error2=OB1_Initialization("01C93357",4,4,4,4,Instr_ID2)
    Calib=zeros(Float64,1000)
    Calib2=zeros(Float64,1000)
    Elveflow_Calibration_Load(raw"C:\Users\Jeremias\Desktop\Julia elveflow test\Calib.txt",Calib,1000)
    Elveflow_Calibration_Load(raw"C:\Users\Jeremias\Desktop\Julia elveflow test\Calib2.txt",Calib2,1000)
    Pressure=Ref{Float64}(0)
    Pressurestoset=Vector{Float64}([0,0,0,0])
    OB1_Set_All_Press(Instr_ID[],Pressurestoset,Calib,4,1000)
    while myflags[1]==1
        OB1_Get_Press(Instr_ID[],1,1,Calib,Pressure,1000)
        myreadpressure[1]=Pressure[]
        OB1_Get_Press(Instr_ID[],2,0,Calib,Pressure,1000)
        myreadpressure[2]=Pressure[]
        OB1_Get_Press(Instr_ID[],3,0,Calib,Pressure,1000)
        myreadpressure[3]=Pressure[]
        OB1_Get_Press(Instr_ID[],4,0,Calib,Pressure,1000)
        myreadpressure[4]=Pressure[]

        OB1_Get_Press(Instr_ID2[],1,1,Calib2,Pressure,1000)
        myreadpressure[5]=Pressure[]
        OB1_Get_Press(Instr_ID2[],2,0,Calib2,Pressure,1000)
        myreadpressure[6]=Pressure[]
        OB1_Get_Press(Instr_ID2[],3,0,Calib2,Pressure,1000)
        myreadpressure[7]=Pressure[]
        OB1_Get_Press(Instr_ID2[],4,0,Calib2,Pressure,1000)
        myreadpressure[8]=Pressure[]

        OB1_Set_All_Press(Instr_ID[],Pressurestoset,Calib,4,1000)
        OB1_Set_All_Press(Instr_ID2[],Pressurestoset1,Calib2,4,1000)
    end
    OB1_Destructor(Instr_ID[])
    OB1_Destructor(Instr_ID2[])
end

function therunner()
    #@everywhere myreadpressure=Array{Float64}(undef,4)
    #@everywhere elveflowkeepgoingflag=1
    myreadpressure=SharedVector{Float64}(8)
    mysetpressure=SharedVector{Float64}(8)
    myflags=SharedVector{UInt8}(2)
    myflags[1]=1
    mygui = @spawnat :any myguifunc(myflags,myreadpressure,mysetpressure)
    myelveflow = @spawnat :any myelveflowfunc(myflags,myreadpressure,mysetpressure)
    fetch(mygui)
    fetch(myelveflow)
end
