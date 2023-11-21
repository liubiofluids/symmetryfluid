using Distributed
@everywhere using Pkg, Blink, SharedArrays, Printf, Spinnaker, JLD2, GLMakie, ImageCore
@everywhere Pkg.develop(PackageSpec(path="C:/Users/Jeremias/.julia/dev/Elveflow"))
@everywhere using Elveflow

@everywhere function thedisplayfunction(myflags,theimagearray)
    img=0
    img=Observable(theimagearray)
    imgplot = image(img,axis = (aspect=DataAspect(),),figure = (figure_padding=0, resolution=size(img[])))
    hidedecorations!(imgplot.axis)
    display(imgplot)
    while myflags[3]==1
        img[]=theimagearray
        sleep(0)
    end
end

@everywhere function myguifunc(myflags,myreadpressure,mysetpressure,theimagearray)
    println("Starting gui func")

    camerafutures=Vector()
    displayfutures=Vector()
    oldcamstate=0
    olddispstate=0

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

        mysetpressure[1]=js(w, Blink.JSString("""document.getElementById("lpb1sl").valueAsNumber"""))
        mysetpressure[2]=js(w, Blink.JSString("""document.getElementById("lpb2sl").valueAsNumber"""))
        mysetpressure[3]=js(w, Blink.JSString("""document.getElementById("lpb3sl").valueAsNumber"""))
        mysetpressure[4]=js(w, Blink.JSString("""document.getElementById("lpb4sl").valueAsNumber"""))
        mysetpressure[5]=js(w, Blink.JSString("""document.getElementById("rpb1sl").valueAsNumber"""))
        mysetpressure[6]=js(w, Blink.JSString("""document.getElementById("rpb2sl").valueAsNumber"""))
        mysetpressure[7]=js(w, Blink.JSString("""document.getElementById("rpb3sl").valueAsNumber"""))
        mysetpressure[8]=js(w, Blink.JSString("""document.getElementById("rpb4sl").valueAsNumber"""))
        #println("Printing type of radio")
        #println(typeof(js(w, Blink.JSString("""document.getElementById("camon").checked"""))))
        #println("Printed type of radio")
        mycurrentcamstate=js(w, Blink.JSString("""document.getElementById("camon").checked"""))
        mycurrentdispstate=js(w, Blink.JSString("""document.getElementById("displayon").checked"""))
        #println("Hitting the if blocks")
        if (mycurrentcamstate)&&(oldcamstate==0)
            println("I'm about to start the new cam process")
            myflags[2]=1
            println("My flag 2 is "*string(myflags[2]))
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
        sleep(0.1)
    end
    myflags[1]=0
end

@everywhere function myelveflowfunc(myflags,myreadpressure,mysetpressure)
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
    Pressurestoset=Vector{Float64}([0,0,0,0])
    Pressurestoset1=Vector{Float64}([0,0,0,0])
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

        Pressurestoset[1]=mysetpressure[1]
        Pressurestoset[2]=mysetpressure[2]
        Pressurestoset[3]=mysetpressure[3]
        Pressurestoset[4]=mysetpressure[4]
        Pressurestoset1[1]=mysetpressure[5]
        Pressurestoset1[2]=mysetpressure[6]
        Pressurestoset1[3]=mysetpressure[7]
        Pressurestoset1[4]=mysetpressure[8]
        OB1_Set_All_Press(Instr_ID[],Pressurestoset,Calib,4,1000)
        OB1_Set_All_Press(Instr_ID2[],Pressurestoset1,Calib2,4,1000)
    end
    OB1_Destructor(Instr_ID[])
    OB1_Destructor(Instr_ID2[])
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
    println("My cam flags 2 is "*string(myflags[2]))
    while myflags[2]==1
        imid, imtimestamp, imexposure = getimage!(cam,theimagearray;normalize=false)
        println(string(time())*" I've got an image")
        jldsave(@sprintf("%.9f",time())*"_"*string(imid)*"_"*string(imtimestamp)*".jld2";theimagearray)
    end
    println("I'm about to stop the camera")
    stop!(cam)
    println("I've stopped the camera")
end



function therunner()
    #@everywhere myreadpressure=Array{Float64}(undef,4)
    #@everywhere elveflowkeepgoingflag=1
    myreadpressure=SharedVector{Float64}(8)
    mysetpressure=SharedVector{Float64}(8)
    theimagearray=Array{UInt8}(undef,2048,2048)
    myflags=SharedVector{UInt8}(4)
    myflags[1]=1
    mygui = @spawnat :any myguifunc(myflags,myreadpressure,mysetpressure,theimagearray)
    myelveflow = @spawnat :any myelveflowfunc(myflags,myreadpressure,mysetpressure)
    fetch(mygui)
    fetch(myelveflow)
end
