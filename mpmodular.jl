using Distributed
@everywhere using Pkg, Blink, SharedArrays, Printf, Spinnaker, Serialization, GLMakie, ImageCore, StaticArrays, LoopVectorization, BenchmarkTools
@everywhere Pkg.develop(PackageSpec(path="C:/Users/Jeremias/.julia/dev/Elveflow"))
@everywhere using Elveflow

@everywhere function thedisplayfunction(theimagearray,myflags)
    #println("Beginning the display function")
    img=Observable(theimagearray)
    #println("Made my makie observable")
    imgplot = image(img,axis = (aspect=DataAspect(),),figure = (figure_padding=0, resolution=size(img[])))
    #println("Made my image plot")
    hidedecorations!(imgplot.axis)
    #println("Hid my decoration")
    display(imgplot)
    #println("Displayed my plot")
    while myflags[3]==1
        img[]=theimagearray
        #println(string(time())*" Updated my array")
        #println(string(theimagearray[1:10]))
        sleep(0)
    end
    println("I'm ending my loop")
end

#@everywhere function thefancypants!(thetime,theperiod,thefancypantsarray)
#    if (0≤thetime)&(thetime≤theperiod)
#        thefancypantsarray[1]=cos(2*π*thetime/theperiod)
#        thefancypantsarray[2]=sin(2*π*thetime/theperiod)
#        thefancypantsarray[3]=0
#    end
#end

function thefancypants!(thetime,theperiod,thefancypantsarray)
end

@everywhere function thepressurecruncher(myflags,myoffsetpressure,mypressurecruncherarray,mymodeamounts,myportassignments,maxabsp,combinedcrunchmodeamounts)
    xflow=(3^(-1/2))*SA_F64[1,0.5,-0.5,-1,-0.5,0.5,0.0,0.0]
    yflow=(3^(-1/2))*2*(1/2)*SA_F64[0,1,1,0,-1,-1,0.0,0.0]
    zflow=(3^(-1/2))*(6^(1/2))*(6^(-1/2))*SA_F64[-1,1,-1,1,-1,1,0.0,0.0]
    opxflow=(3^(-1/2))*SA_F64[1,-.5,-.5,1,-.5,-.5,0.0,0.0]
    opyflow=0.5*SA_F64[0,1,-1,0,1,-1,0.0,0.0]
    biasflow=(6^(-1/2))*SA_F64[1,1,1,1,1,1,0.0,0.0]

    thefancypantsarray=MVector{6,Float64}(0,0,0,0,0,0)
    starttime=time()
    firstflag=1
    secondflag=1
    println("One print")
    while myflags[5]==1
        function thefancypants!(thetime,theperiod,thefancypantsarray)
            println(string(123))
        end

        thefancypants!(mod(time()-starttime,2),2,thefancypantsarray)
        if (time()>(starttime+30))&(firstflag==1)
            println("First parse")
            eval(Meta.parse("function thefancypants!(thetime,theperiod,thefancypantsarray);if (0<=thetime)&(thetime<=theperiod);thefancypantsarray[1]=cos(2*pi*thetime/theperiod);thefancypantsarray[2]=sin(2*pi*thetime/theperiod);thefancypantsarray[3]=0;end;println(string(234));end"))
            firstflag=0
        end
        if (time()>(starttime+60))&(secondflag==1)
            println("Second parse")
            eval(Meta.parse("function thefancypants!(thetime,theperiod,thefancypantsarray);println(string(345));end"))
            secondflag=0
        end
        #thefancypants!(time(),2,thefancypantsarray)
        @tturbo for i = 1:6
            combinedcrunchmodeamounts[i]=mymodeamounts[i]+thefancypantsarray[i]
        end
        @tturbo for i = 1:8
            mypressurecruncherarray[i]=clamp(myoffsetpressure[i]+(mymodeamounts[1]+thefancypantsarray[1])*xflow[myportassignments[i]]+(mymodeamounts[2]+thefancypantsarray[2])*yflow[myportassignments[i]]+(mymodeamounts[3]+thefancypantsarray[3])*zflow[myportassignments[i]]+mymodeamounts[4]*biasflow[myportassignments[i]]+mymodeamounts[5]*opxflow[myportassignments[i]]+mymodeamounts[6]*opyflow[myportassignments[i]],-maxabsp[1],maxabsp[1])
        end
        end
end

@everywhere function theelveflowfunction(myflags,myreadpressure,myoffsetpressure,mypressurecruncherarray)
    Instr_ID=Ref{Int32}(0)
    Instr_ID2=Ref{Int32}(1)
    error=OB1_Initialization("01CB2A4A",4,4,4,4,Instr_ID)
    println("Finished first initialization")
    error2=OB1_Initialization("01C93357",4,4,4,4,Instr_ID2)
    println("Finished second initialization")
    Calib=zeros(Float64,1000)
    Calib2=zeros(Float64,1000)
    #OB1_Calib(Instr_ID[],Calib,1000)
    #Elveflow_Calibration_Save(raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib.txt",Calib,1000)
    #OB1_Calib(Instr_ID2[],Calib2,1000)
    #Elveflow_Calibration_Save(raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib2.txt",Calib2,1000)
    Elveflow_Calibration_Load(raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib.txt",Calib,1000)
    println("Finished loading first calibration")
    Elveflow_Calibration_Load(raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib2.txt",Calib2,1000)
    println("Finished loading second calibration")
    Pressure=Ref{Float64}(0)
    Pressurestoset=Vector{Float64}([0,0,0,0,0,0,0,0])
    #Pressurestoset=Vector{Float64}([0,0,0,0])
    OB1_Set_All_Press(Instr_ID[],Pressurestoset[1:4],Calib,4,1000)
    OB1_Set_All_Press(Instr_ID2[],Pressurestoset[5:8],Calib,4,1000)
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

        OB1_Set_All_Press(Instr_ID[],mypressurecruncherarray[1:4],Calib,4,1000)
        OB1_Set_All_Press(Instr_ID2[],mypressurecruncherarray[5:8],Calib2,4,1000)
    end
    OB1_Destructor(Instr_ID[])
    OB1_Destructor(Instr_ID2[])
end

@everywhere function savebyserial(mypath,myobject)
    open(fid->serialize(fid, myobject), mypath, "w")
end

@everywhere function thecamerafunction(theimagearray,myflags)
    println("I'm about to list the cameras")
    camlist = CameraList()
    cam = camlist[0]
    acquisitionmode!(cam, "Continuous")
    buffermode!(cam, "NewestFirst")
    pixelformat!(cam, "Mono8")
    println("I'm about to start the camera")
    start!(cam)
    println("The camera is starting")
    #println("My cam flags 2 is "*string(myflags[2]))
    while myflags[2]==1
        imid, imtimestamp, imexposure = getimage!(cam,theimagearray;normalize=false)
        #println(string(time())*" I've got an image")
        #println("Cam sees "*string(theimagearray[1:10]))
        #println(typeof(theimagearray))
        #println(size(theimagearray))
        if myflags[4]==1
            #println("Saving image!")
            #jldsave(@sprintf("%.9f",time())*"_"*string(imid)*"_"*string(imtimestamp)*".jld2";theimagearray) #Apparently JLD2 is slow
            savebyserial(@sprintf("%.9f",time())*"_"*string(imid)*"_"*string(imtimestamp)*".slz",theimagearray) #Apparently serializing is fast
        end
    end
    println("I'm about to stop the camera")
    stop!(cam)
    println("I've stopped the camera")
end

function therunner()
    #@everywhere myreadpressure=Array{Float64}(undef,4)
    #@everywhere elveflowkeepgoingflag=1
    myreadpressure=SharedVector{Float64}(8)
    myoffsetpressure=SharedVector{Float64}(8)
    theimagearray=SharedArray{UInt8}((2048,2048))
    myflags=SharedVector{UInt8}(5)
    mypressurecruncherarray=SharedArray{Float64}(8)
    mymodeamounts=SharedVector{Float64}(6)
    myportassignments=SharedVector{Int}(8)
    maxabsp=SharedVector{Float64}(1)
    combinedcrunchmodeamounts=SharedVector{Float64}(6)
    #myflags[1]=1
    #mygui = @spawnat :any myguifunc(myflags,myreadpressure,mysetpressure,theimagearray)

    pumpfutures=Vector()
    crunchfutures=Vector()
    camerafutures=Vector()
    displayfutures=Vector()
    oldpumpstate=0
    oldcrunchstate=0
    oldcamstate=0
    olddispstate=0
    oldrecordstate=0
    oldtextcustom=""

    w = Window()
    println("Opened window")
    #load!(w,"mpcamtrack.html")
    title(w,"Julia mpcamtrack")
    f=open("C:/Users/Jeremias/gitrepos/mpcamtrackjulia/mpcamtrack.html") do file
        read(file,String)
    end
    body!(w,f, async=false)
    println("Finished reading file")
    #loadhtml(w,f)
    println("HTML is loaded")

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

        combinedcrunchmodestringholder=Printf.format.(Ref(Printf.Format("%.2f")),combinedcrunchmodeamounts)
        js(w, Blink.JSString("""document.getElementById("finalxam").innerHTML="$(combinedcrunchmodestringholder[1])" """))
        js(w, Blink.JSString("""document.getElementById("finalyam").innerHTML="$(combinedcrunchmodestringholder[2])" """))
        js(w, Blink.JSString("""document.getElementById("finalzam").innerHTML="$(combinedcrunchmodestringholder[3])" """))
        js(w, Blink.JSString("""document.getElementById("finalbam").innerHTML="$(combinedcrunchmodestringholder[4])" """))
        js(w, Blink.JSString("""document.getElementById("finalopxam").innerHTML="$(combinedcrunchmodestringholder[5])" """))
        js(w, Blink.JSString("""document.getElementById("finalopyam").innerHTML="$(combinedcrunchmodestringholder[6])" """))

        myoffsetpressure[1]=js(w, Blink.JSString("""document.getElementById("lpb1sl").valueAsNumber"""))
        myoffsetpressure[2]=js(w, Blink.JSString("""document.getElementById("lpb2sl").valueAsNumber"""))
        myoffsetpressure[3]=js(w, Blink.JSString("""document.getElementById("lpb3sl").valueAsNumber"""))
        myoffsetpressure[4]=js(w, Blink.JSString("""document.getElementById("lpb4sl").valueAsNumber"""))
        myoffsetpressure[5]=js(w, Blink.JSString("""document.getElementById("rpb1sl").valueAsNumber"""))
        myoffsetpressure[6]=js(w, Blink.JSString("""document.getElementById("rpb2sl").valueAsNumber"""))
        myoffsetpressure[7]=js(w, Blink.JSString("""document.getElementById("rpb3sl").valueAsNumber"""))
        myoffsetpressure[8]=js(w, Blink.JSString("""document.getElementById("rpb4sl").valueAsNumber"""))

        mymodeamounts[1]=js(w, Blink.JSString("""document.getElementById("xmodesl").valueAsNumber"""))
        mymodeamounts[2]=js(w, Blink.JSString("""document.getElementById("ymodesl").valueAsNumber"""))
        mymodeamounts[3]=js(w, Blink.JSString("""document.getElementById("zmodesl").valueAsNumber"""))
        mymodeamounts[4]=js(w, Blink.JSString("""document.getElementById("bmodesl").valueAsNumber"""))
        mymodeamounts[5]=js(w, Blink.JSString("""document.getElementById("opxmodesl").valueAsNumber"""))
        mymodeamounts[6]=js(w, Blink.JSString("""document.getElementById("opymodesl").valueAsNumber"""))

        mycurrentpumpstate=js(w, Blink.JSString("""document.getElementById("pumpon").checked"""))
        mycurrentcrunchstate=js(w, Blink.JSString("""document.getElementById("crunchon").checked"""))
        mycurrentcamstate=js(w, Blink.JSString("""document.getElementById("camon").checked"""))
        mycurrentdispstate=js(w, Blink.JSString("""document.getElementById("displayon").checked"""))
        mycurrentrecordingstate=js(w, Blink.JSString("""document.getElementById("recordon").checked"""))
        #mycurrenttextcustom=js(w, Blink.JSString("""document.getElementById("mytextcustom").value"""))
        #println(mycurrenttextcustom)
        myportassignments[1]=parse(Int,js(w, Blink.JSString("""document.getElementById("portl1box").value""")))
        myportassignments[2]=parse(Int,js(w, Blink.JSString("""document.getElementById("portl2box").value""")))
        myportassignments[3]=parse(Int,js(w, Blink.JSString("""document.getElementById("portl3box").value""")))
        myportassignments[4]=parse(Int,js(w, Blink.JSString("""document.getElementById("portl4box").value""")))
        myportassignments[5]=parse(Int,js(w, Blink.JSString("""document.getElementById("portr1box").value""")))
        myportassignments[6]=parse(Int,js(w, Blink.JSString("""document.getElementById("portr2box").value""")))
        myportassignments[7]=parse(Int,js(w, Blink.JSString("""document.getElementById("portr3box").value""")))
        myportassignments[8]=parse(Int,js(w, Blink.JSString("""document.getElementById("portr4box").value""")))

        maxabsp[1]=js(w, Blink.JSString("""document.getElementById("maxabspsl").valueAsNumber"""))
        #println("Hitting the if block")
        #println("mycurrentpumpstate is "*string(mycurrentpumpstate))
        #println("oldpumpstateis "*string(oldpumpstate))
        if (mycurrentpumpstate)&&(oldpumpstate==0)
            println("I'm about to start the new pump process")
            myflags[1]=1
            push!(pumpfutures,@spawnat :any theelveflowfunction(myflags,myreadpressure,myoffsetpressure,mypressurecruncherarray))
            println("I've started the new pump process")
            oldpumpstate=1
        elseif (!mycurrentpumpstate)&&(oldpumpstate==1)
            myflags[1]=0
            println("I'm fetching the new pump process")
            fetch(pumpfutures[end])
            println("I've fetched the new pump process")
            oldpumpstate=0
        end
        if (mycurrentcrunchstate)&&(oldcrunchstate==0)
            println("I'm about to start the new crunch process")
            myflags[5]=1
            push!(crunchfutures,@spawnat :any thepressurecruncher(myflags,myoffsetpressure,mypressurecruncherarray,mymodeamounts,myportassignments,maxabsp,combinedcrunchmodeamounts))
            println("I've started the new crunch process")
            oldcrunchstate=1
        elseif (!mycurrentcrunchstate)&&(oldcrunchstate==1)
            myflags[5]=0
            println("I'm fetching the new crunch process")
            fetch(crunchfutures[end])
            println("I've fetched the new crunch process")
            oldcrunchstate=0
        end
        if (mycurrentcamstate)&&(oldcamstate==0)
            println("I'm about to start the new cam process")
            myflags[2]=1
            #println("My flag 2 is "*string(myflags[2]))
            push!(camerafutures,@spawnat :any thecamerafunction(theimagearray,myflags))
            println("I've started the new cam process")
            oldcamstate=1
        elseif (!mycurrentcamstate)&&(oldcamstate==1)
            myflags[2]=0
            println("I'm fetching the new cam process")
            fetch(camerafutures[end])
            println("I've fetched the new cam process")
            oldcamstate=0
        end
        if (mycurrentdispstate)&&(olddispstate==0)
            println("I'm about to start the new disp process")
            myflags[3]=1
            push!(displayfutures,@spawnat :any thedisplayfunction(theimagearray,myflags))
            println("I've started the new disp process")
            olddispstate=1
        elseif (!mycurrentdispstate)&&(olddispstate==1)
            myflags[3]=0
            println("I'm fetching the new disp process")
            fetch(displayfutures[end])
            println("I've fetched the new disp process")
            olddispstate=0
        end
        if (mycurrentrecordingstate)&&(oldrecordstate==0)
            myflags[4]=1
            oldrecordstate=1
        elseif (!mycurrentrecordingstate)&&(oldrecordstate==1)
            myflags[4]=0
            oldrecordstate=0
        end
        #if (mycurrenttextcustom!=oldtextcustom)
        #    oldtextcustom=mycurrenttextcustom
        #    println("I'm about to parse")
        #    println(mycurrenttextcustom)
        #    eval(Meta.parse(mycurrenttextcustom))
        #    println("I've parsed")
        #end
        sleep(0.1)
    end
    myflags.=0

    #myelveflow = @spawnat :any myelveflowfunc(myflags,myreadpressure,mysetpressure)
    #fetch(mygui)
    if length(pumpfutures)>0
        fetch(pumpfutures[end])
    end
    if length(crunchfutures)>0
        fetch(crunchfutures[end])
    end
    if length(camerafutures)>0
        fetch(camerafutures[end])
    end
    if length(displayfutures)>0
        fetch(displayfutures[end])
    end
end
