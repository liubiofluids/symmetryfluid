using Pkg: installed
using Distributed
@everywhere using Pkg,
    Blink,
    SharedArrays,
    Printf,
    Spinnaker,
    Serialization,
    GLMakie,
    ImageCore,
    StaticArrays,
    BenchmarkTools,
    Images,
    CUDA,
    Makie.GeometryBasics,
    Dates,
    Glob,
    ProgressMeter
@everywhere Pkg.develop(PackageSpec(path = "C:/Users/Jeremias/.julia/dev/Elveflow"))
@everywhere Pkg.develop(PackageSpec(path = "C:/Users/Jeremias/.julia/dev/PriorScientific"))
@everywhere using Elveflow, PriorScientific

@everywhere function bestguesstrackingstartfunction!(theimagearray, r)
    maxintensitylocation = argmax(theimagearray)
    copyto!(r, maxintensitylocation)
end

@everywhere function thetrackerfunction!(
    theimagearray,
    myflags,
    r,
    clickedlocation,
    imageanalysisparameters,
)
    imagesize = [size(theimagearray, 1), size(theimagearray, 2)]
    clipsize = Int.(floor.([imageanalysisparameters[1], imageanalysisparameters[2]]))
    oldclipsize = Int.(floor.([imageanalysisparameters[1], imageanalysisparameters[2]]))
    myclippedview = Array{UInt8}(undef, clipsize[1], clipsize[2])
    myfilteredclippedview = Array{Float32}(undef, clipsize[1], clipsize[2])
    clipbotbot = r .- Int.(floor.(clipsize / 2))
    myclippedbool = Array{Bool}(undef, clipsize[1], clipsize[2])
    currentthreshold = imageanalysisparameters[3]
    mykernel = Kernel.gaussian(imageanalysisparameters[4])
    oldgaussianparameter = imageanalysisparameters[4]
    mylabelled = Array{UInt32}(undef, clipsize[1], clipsize[2])
    while myflags[6] == 1
        if myflags[10] == 1
            bestguesstrackingstartfunction!(theimagearray, r)
        end
        if myflags[12] == 1
            copyto!(r, clickedlocation)
            myflags[12] = 0
        end
        @. clipsize = Int(floor([imageanalysisparameters[1], imageanalysisparameters[2]]))
        if clipsize != oldclipsize
            oldclipsize .= clipsize
            myclippedview = Array{UInt8}(undef, clipsize[1], clipsize[2])
            myfilteredclippedview = Array{Float32}(undef, clipsize[1], clipsize[2])
            myclippedbool = Array{Bool}(undef, clipsize[1], clipsize[2])
            mylabelled = Array{UInt32}(undef, clipsize[1], clipsize[2])
        end
        currentthreshold = imageanalysisparameters[3]
        if oldgaussianparameter != imageanalysisparameters[4]
            mykernel = Kernel.gaussian(imageanalysisparameters[4])
            oldgaussianparameter = imageanalysisparameters[4]
        end
        @. clipbotbot = clamp(r - Int(floor(clipsize / 2)), 1, imagesize - clipsize + 1)
        clipclipper!(clipsize, myclippedview, theimagearray, clipbotbot)
        imfilter!(myfilteredclippedview, myclippedview, mykernel)
        thresholdarray!(myclippedbool, myfilteredclippedview, currentthreshold)
        label_components!(mylabelled, myclippedbool)
        centroids = component_centroids(mylabelled)
        if length(centroids) != 1
            newframecenter!(centroids, r, clipbotbot)
        end
    end
    println("I'm ending my tracking loop")
end

@everywhere function newframecenter!(centroids, r, clipbotbot)
    mycentroiddistances2 = MVector{length(centroids) - 1,Float32}(undef)
    mycentroiddistances2 .= 0
    @fastmath @inbounds @simd for centroidindex = 1:length(centroids)-1
        mycentroiddistances2[centroidindex] =
            centroids[centroidindex][1]^2 + centroids[centroidindex][2]^2
    end
    thesmallestindex = argmin(mycentroiddistances2)
    r .=
        clipbotbot .+
        Int.(
            floor.(MVector(centroids[thesmallestindex][1], centroids[thesmallestindex][2]))
        )
end


@everywhere function clipclipper!(clipsize, myclippedview, theimagearray, clipbotbot)
    @fastmath @inbounds for j = 1:clipsize[2]
        @simd for i = 1:clipsize[1]
            myclippedview[i, j] = theimagearray[clipbotbot[1]+i-1, clipbotbot[2]+j-1]
        end
    end
end

@everywhere function thresholdarray!(myclippedbool, myview, currentthreshold)
    @fastmath @inbounds @simd for idx in eachindex(myview)
        myclippedbool[idx] = myview[idx] > currentthreshold
    end
end

@everywhere function thedisplayfunction(
    theimagearray,
    myflags,
    clickedlocation,
    r,
    imageanalysisparameters,
    dest,
)
    img = Observable(theimagearray)
    imgplot = image(
        img,
        axis = (aspect = DataAspect(),),
        figure = (figure_padding = 0, size = (600, 600)),
    )
    hidedecorations!(imgplot.axis)
    display(imgplot)

    on(events(imgplot).mousebutton, priority = 2) do event
        if event.button == Mouse.left && event.action == Mouse.press
            windowsize = decompose(Point{2,Float64}, events(imgplot).window_area[])[4]
            mouseclicklocation = mouseposition(imgplot)
            if (mouseclicklocation[1] >= 1) &&
               (mouseclicklocation[1] <= windowsize[1]) &&
               (mouseclicklocation[2] >= 1) &&
               (mouseclicklocation[2] <= windowsize[2])#For some reason the clicks on a Makie window sometimes report coordinates outside the domain of the image. This check filters the bad events.
                clickedlocation[1] = clamp(
                    Int(floor(2048 * ((mouseclicklocation[1] / windowsize[1])))),
                    1,
                    2048,
                )
                clickedlocation[2] = clamp(
                    Int(floor(2048 * ((mouseclicklocation[2] / windowsize[2])))),
                    1,
                    2048,
                )
                myflags[12] = 1
            end
        end
    end

    imagesize = [size(theimagearray, 1), size(theimagearray, 2)]
    clipsize = Int.(floor.([imageanalysisparameters[1], imageanalysisparameters[2]]))
    clipbotbot = clamp.(r .- Int.(floor.(clipsize ./ 2)), 1, imagesize .- clipsize .+ 1)
    oldtrackingstate = 0

    mypolyaoi = Polygon(Point2f[(150, 450), (450, 450), (450, 150), (150, 150)])
    mypolyaoivar =
        poly!(mypolyaoi, color = :transparent, strokecolor = :red, strokewidth = 2)
    delete!(imgplot.axis.scene, mypolyaoivar)

    mytrackedpoint = Point2f[(r[1], r[2])]
    mytrackedpointvar = scatter!(mytrackedpoint, markersize = 5, color = :red, alpha = 0.5)
    delete!(imgplot.axis.scene, mytrackedpointvar)

    mydestinationpoint = Point2f[(dest[1], dest[2])]
    mydestinationpointvar =
        scatter!(mydestinationpoint, markersize = 5, color = :green, alpha = 0.5)
    delete!(imgplot.axis.scene, mydestinationpointvar)

    while myflags[3] == 1
        img[] = theimagearray
        if myflags[6] == 1
            if oldtrackingstate == 1
                delete!(imgplot.axis.scene, mypolyaoivar)
                delete!(imgplot.axis.scene, mytrackedpointvar)
                delete!(imgplot.axis.scene, mydestinationpointvar)
            end

            @. clipsize =
                Int(floor([imageanalysisparameters[1], imageanalysisparameters[2]]))
            @. clipbotbot = clamp(r - Int(floor(clipsize / 2)), 1, imagesize - clipsize + 1)
            polygonaoipoints = Point2f[
                (clipbotbot[1], clipbotbot[2]),
                ((clipbotbot[1] + clipsize[1]), clipbotbot[2]),
                ((clipbotbot[1] + clipsize[1]), (clipbotbot[2] + clipsize[2])),
                (clipbotbot[1], (clipbotbot[2] + clipsize[2])),
            ]
            mypolyaoi = Polygon(polygonaoipoints)
            mypolyaoivar = poly!(
                mypolyaoi,
                color = :transparent,
                strokecolor = :red,
                strokewidth = 2,
                alpha = 0.5,
            )
            mytrackedpoint = Point2f[(r[1], r[2])]
            mytrackedpointvar =
                scatter!(mytrackedpoint, markersize = 5, color = :red, alpha = 0.5)

            mydestinationpoint = Point2f[(dest[1], dest[2])]
            mydestinationpointvar =
                scatter!(mydestinationpoint, markersize = 5, color = :green, alpha = 0.5)

            if oldtrackingstate == 0
                oldtrackingstate = 1
            end
        elseif myflags[6] == 0 && oldtrackingstate == 1
            delete!(imgplot.axis.scene, mypolyaoivar)
            delete!(imgplot.axis.scene, mytrackedpointvar)
            delete!(imgplot.axis.scene, mydestinationpointvar)
            oldtrackingstate = 0
        end
        sleep(0)
    end
    println("I'm ending my displaying loop")
end

@everywhere function thefancypants!(
    t,
    thefancypantsarray,
    instructionarray,
    landmarksarray,
    thefancypantspos,
    calctype,
)
    @fastmath @inbounds for myinstructionsetround in axes(instructionarray, 2)
        if t > landmarksarray[1, myinstructionsetround+1]
            continue
        else
            t₀ = landmarksarray[1, myinstructionsetround]
            t₁ = landmarksarray[1, myinstructionsetround+1]
            therisingtime = (t - t₀) / instructionarray[1, myinstructionsetround]
            therisingtimedot = 1 / instructionarray[1, myinstructionsetround]
            thefallingtime = (t₁ - t) / instructionarray[1, myinstructionsetround]
            thefallingtimedot = -1 / instructionarray[1, myinstructionsetround]
            if instructionarray[2, myinstructionsetround] == 1#linear
                therisingtimeexp = therisingtime
                therisingtimeexpdot = therisingtimedot
                thefallingtimeexp = thefallingtime
                thefallingtimeexpdot = thefallingtimedot
            end
            if instructionarray[3, myinstructionsetround] == 1#cart
                if instructionarray[4, myinstructionsetround] == 1#diff
                    if 1 in calctype
                        @simd for velindex = 1:3
                            thefancypantsarray[velindex] =
                                instructionarray[velindex+4, myinstructionsetround] *
                                therisingtimeexpdot
                        end
                        @simd for velindex = 4:6
                            thefancypantsarray[velindex] = 0
                        end
                    end
                    if 0 in calctype
                        @simd for posindex in axes(thefancypantspos, 1)
                            thefancypantspos[posindex] =
                                (
                                    instructionarray[posindex+4, myinstructionsetround] +
                                    landmarksarray[posindex+1, myinstructionsetround]
                                ) * therisingtimeexp +
                                (landmarksarray[posindex+1, myinstructionsetround]) *
                                thefallingtimeexp
                        end
                    end
                elseif instructionarray[4, myinstructionsetround] == 2#point
                    if 1 in calctype
                        @simd for velindex = 1:3
                            thefancypantsarray[velindex] =
                                instructionarray[velindex+4, myinstructionsetround] *
                                therisingtimeexpdot +
                                landmarksarray[velindex+1, myinstructionsetround] *
                                thefallingtimeexpdot
                        end
                        @simd for velindex = 4:6
                            thefancypantsarray[velindex] = 0
                        end
                    end
                    if 0 in calctype
                        @simd for posindex in axes(thefancypantspos, 1)
                            thefancypantspos[posindex] =
                                instructionarray[posindex+4, myinstructionsetround] *
                                therisingtimeexp +
                                landmarksarray[posindex+1, myinstructionsetround] *
                                thefallingtimeexp
                        end
                    end
                end
            elseif instructionarray[3, myinstructionsetround] == 2#cyl
                if instructionarray[4, myinstructionsetround] == 1#phase
                    ϕ =
                        therisingtimeexp * instructionarray[7, myinstructionsetround] +
                        thefallingtimeexp * instructionarray[6, myinstructionsetround]
                    ϕdot =
                        therisingtimeexpdot * instructionarray[7, myinstructionsetround] +
                        thefallingtimeexpdot * instructionarray[6, myinstructionsetround]
                    if instructionarray[5, myinstructionsetround] == 3#z
                        if 1 in calctype
                            thefancypantsarray[1] =
                                -sin(ϕ) * ϕdot * instructionarray[8, myinstructionsetround]
                            thefancypantsarray[2] =
                                cos(ϕ) * ϕdot * instructionarray[8, myinstructionsetround]
                            @simd for velindex = 3:6
                                thefancypantsarray[velindex] = 0
                            end
                        end
                        if 0 in calctype
                            thefancypantspos[1] =
                                (cos(ϕ) - cos(instructionarray[6, myinstructionsetround])) *
                                instructionarray[8, myinstructionsetround] +
                                landmarksarray[2, myinstructionsetround]
                            thefancypantspos[2] =
                                (sin(ϕ) - sin(instructionarray[6, myinstructionsetround])) *
                                instructionarray[8, myinstructionsetround] +
                                landmarksarray[3, myinstructionsetround]
                            thefancypantspos[3] = landmarksarray[4, myinstructionsetround]
                        end
                    end
                elseif instructionarray[4, myinstructionsetround] == 2#radius
                    if instructionarray[5, myinstructionsetround] == 1#dim
                        if instructionarray[6, myinstructionsetround] == 3#z
                            if instructionarray[7, myinstructionsetround] == 1#x
                                if 1 in calctype
                                    thefancypantsarray[1] =
                                        instructionarray[8, myinstructionsetround] *
                                        sign(
                                            cos(instructionarray[9, myinstructionsetround]),
                                        ) *
                                        therisingtimeexpdot
                                    thefancypantsarray[2] =
                                        instructionarray[8, myinstructionsetround] *
                                        sign(
                                            cos(instructionarray[9, myinstructionsetround]),
                                        ) *
                                        tan(instructionarray[9, myinstructionsetround]) *
                                        therisingtimeexpdot
                                    @simd for velindex = 3:6
                                        thefancypantsarray[velindex] = 0
                                    end
                                end
                                if 0 in calctype
                                    thefancypantspos[1] =
                                        (
                                            instructionarray[8, myinstructionsetround] *
                                            sign(
                                                cos(
                                                    instructionarray[
                                                        9,
                                                        myinstructionsetround,
                                                    ],
                                                ),
                                            ) + landmarksarray[2, myinstructionsetround]
                                        ) * therisingtimeexp +
                                        landmarksarray[2, myinstructionsetround] *
                                        thefallingtimeexp
                                    thefancypantspos[2] =
                                        (
                                            instructionarray[8, myinstructionsetround] *
                                            sign(
                                                cos(
                                                    instructionarray[
                                                        9,
                                                        myinstructionsetround,
                                                    ],
                                                ),
                                            ) *
                                            tan(instructionarray[9, myinstructionsetround]) +
                                            landmarksarray[3, myinstructionsetround]
                                        ) * therisingtimeexp +
                                        landmarksarray[3, myinstructionsetround] *
                                        thefallingtimeexp
                                    thefancypantspos[3] =
                                        landmarksarray[4, myinstructionsetround]
                                end
                            end
                        end
                    end
                end
            end
        end
        break
    end
end

@everywhere function thefancypantsport!(
    t,
    thefancypantsportarray,
    instructionportarray,
    landmarksportarray,
    thefancypantsportconfig,
    calctype,
)
    @fastmath @inbounds for myinstructionsetround in axes(instructionportarray, 2)
        if t > landmarksportarray[1, myinstructionsetround+1]
            continue
        else
            t₀ = landmarksportarray[1, myinstructionsetround]
            t₁ = landmarksportarray[1, myinstructionsetround+1]
            therisingtime = (t - t₀) / instructionportarray[1, myinstructionsetround]
            therisingtimedot = 1 / instructionportarray[1, myinstructionsetround]
            thefallingtime = (t₁ - t) / instructionportarray[1, myinstructionsetround]
            thefallingtimedot = -1 / instructionportarray[1, myinstructionsetround]
            if instructionportarray[2, myinstructionsetround] == 1#linear
                therisingtimeexp = therisingtime
                therisingtimeexpdot = therisingtimedot
                thefallingtimeexp = thefallingtime
                thefallingtimeexpdot = thefallingtimedot
            end
            if instructionportarray[3, myinstructionsetround] == 1#block
                if instructionportarray[4, myinstructionsetround] == 2#point
                    if 0 in calctype
                        @simd for posindex in axes(thefancypantsportconfig, 1)
                            thefancypantsportconfig[posindex] =
                                instructionportarray[posindex+4, myinstructionsetround]
                        end
                    end
                end
            end
        end
        break
    end
end

@everywhere function fancypantslandmarks!(
    instructionarray,
    landmarksarray,
    customcrunchmetadata,
)
    t₀ = landmarksarray[1, 1]
    t₁ = landmarksarray[1, 1]
    thefancypantspos = MVector{3,Float64}(0, 0, 0)
    thefancypantsarray = MVector{6,Float64}(0, 0, 0, 0, 0, 0)
    @fastmath @inbounds for myinstructionsetround = 1:customcrunchmetadata[1]
        t₀ = t₁
        t₁ = t₁ + instructionarray[1, myinstructionsetround]
        landmarksarray[1, myinstructionsetround+1] = t₁
        thefancypants!(
            t₁,
            thefancypantsarray,
            instructionarray,
            landmarksarray,
            thefancypantspos,
            [0],
        )
        @simd for posindex in axes(thefancypantspos, 1)
            landmarksarray[posindex+1, myinstructionsetround+1] = thefancypantspos[posindex]
        end
    end
end

@everywhere function fancypantslandmarksport!(
    instructionportarray,
    landmarksportarray,
    customportcrunchmetadata,
)
    t₀ = landmarksportarray[1, 1]
    t₁ = landmarksportarray[1, 1]
    thefancypantsportconfig = MVector{8,Float64}(0, 0, 0, 0, 0, 0, 0, 0)
    thefancypantsportarray = MVector{8,Float64}(0, 0, 0, 0, 0, 0, 0, 0)
    @fastmath @inbounds for myinstructionsetround = 1:customportcrunchmetadata[1]
        t₀ = t₁
        t₁ = t₁ + instructionportarray[1, myinstructionsetround]
        landmarksportarray[1, myinstructionsetround+1] = t₁
        thefancypantsport!(
            t₁,
            thefancypantsportarray,
            instructionportarray,
            landmarksportarray,
            thefancypantsportconfig,
            [0],
        )
        @simd for posindex in axes(thefancypantsportconfig, 1)
            landmarksportarray[posindex+1, myinstructionsetround] =
                thefancypantsportconfig[posindex]
        end
    end
end

@everywhere function thepressurecruncher(
    myflags,
    mypressurecruncherarray,
    mymodeamounts,
    mymodescalingamounts,
    myportassignments,
    combinedcrunchmodeamounts,
    landmarksarray,
    instructionarray,
    customcrunchmetadata,
    r,
    trackplanescale,
    custommodescale,
    customportscale,
    instructionportarray,
    landmarksportarray,
    customportcrunchmetadata,
    trackcoords,
    dest,
)
    xflow = (3^(-1 / 2)) * SA_F64[1, 0.5, -0.5, -1, -0.5, 0.5, 0.0, 0.0]
    yflow = (3^(-1 / 2)) * 2 * (1 / 2) * SA_F64[0, 1, 1, 0, -1, -1, 0.0, 0.0]
    zflow =
        (3^(-1 / 2)) * (6^(1 / 2)) * (6^(-1 / 2)) * SA_F64[-1, 1, -1, 1, -1, 1, 0.0, 0.0]
    opxflow = (3^(-1 / 2)) * SA_F64[1, -0.5, -0.5, 1, -0.5, -0.5, 0.0, 0.0]
    opyflow = 0.5 * SA_F64[0, 1, -1, 0, 1, -1, 0.0, 0.0]
    biasflow = (6^(-1 / 2)) * SA_F64[1, 1, 1, 1, 1, 1, 0.0, 0.0]

    thefancypantsarray = MVector{6,Float64}(0, 0, 0, 0, 0, 0)
    thefancypantspos = MVector{3,Float64}(0, 0, 0)

    thefancypantsportarray = MVector{8,Float64}(0, 0, 0, 0, 0, 0, 0, 0)
    thefancypantsportconfig = MVector{8,Float64}(0, 0, 0, 0, 0, 0, 0, 0)

    starttime = time()

    rollingcrunchtimeindex = 1
    startcrunch = starttime
    avgcrunchtime = 0.0

    while myflags[5] == 1
        if myflags[7] == 1 && myflags[6] == 1
            thefancypants!(
                (time() - starttime) % landmarksarray[1, customcrunchmetadata[1]+1],
                thefancypantsarray,
                instructionarray,
                landmarksarray,
                thefancypantspos,
                [0 1],
            )
            @fastmath @inbounds @simd for posindex in eachindex(dest)
                dest[posindex] = clamp(Int(floor(thefancypantspos[posindex])), 1, 2048)
            end
            if rollingcrunchtimeindex == 100
                newcrunchtime = time()
                avgcrunchtime = (newcrunchtime - startcrunch) / 100
                startcrunch = newcrunchtime
                rollingcrunchtimeindex = 1
            else
                rollingcrunchtimeindex = rollingcrunchtimeindex + 1
            end
            @fastmath @inbounds @simd for trackedindex = 1:2
                thefancypantsarray[trackedindex] =
                    thefancypantsarray[trackedindex] +
                    trackplanescale[trackedindex] *
                    (thefancypantspos[trackedindex] - r[trackcoords[trackedindex]]) /
                    avgcrunchtime
            end
        elseif myflags[7] == 1
            thefancypants!(
                (time() - starttime) % landmarksarray[1, customcrunchmetadata[1]+1],
                thefancypantsarray,
                instructionarray,
                landmarksarray,
                thefancypantspos,
                [1],
            )
        else
            thefancypantsarray .= 0
        end
        if myflags[11] == 1
            thefancypantsport!(
                (time() - starttime) % landmarksportarray[1, customportcrunchmetadata[1]+1],
                thefancypantsportarray,
                instructionportarray,
                landmarksportarray,
                thefancypantsportconfig,
                [0],
            )
        else
            thefancypantsportconfig .= 0
        end
        @fastmath @inbounds @simd for i in eachindex(combinedcrunchmodeamounts)
            combinedcrunchmodeamounts[i] =
                mymodeamounts[i] + custommodescale[1] * thefancypantsarray[i]
        end
        @fastmath @inbounds @simd for i in eachindex(mypressurecruncherarray)
            mypressurecruncherarray[i] =
                combinedcrunchmodeamounts[1] *
                mymodescalingamounts[1] *
                xflow[myportassignments[i]] +
                combinedcrunchmodeamounts[2] *
                mymodescalingamounts[2] *
                yflow[myportassignments[i]] +
                combinedcrunchmodeamounts[3] *
                mymodescalingamounts[3] *
                zflow[myportassignments[i]] +
                combinedcrunchmodeamounts[4] * biasflow[myportassignments[i]] +
                combinedcrunchmodeamounts[5] * opxflow[myportassignments[i]] +
                combinedcrunchmodeamounts[6] * opyflow[myportassignments[i]] +
                customportscale[1] * thefancypantsportconfig[myportassignments[i]]
        end
    end
end

@everywhere function theelveflowfunction(
    pressurepumpflags,
    myreadpressure,
    mypressurecruncherarray,
    myoffsetpressure,
    maxabsp,
    myportscaling,
    thetopleveldatadir,
    recordfoldernumber,
)
    Instr_ID = Ref{Int32}(0)
    Instr_ID2 = Ref{Int32}(1)
    error = OB1_Initialization("01CB2A4A", 4, 4, 4, 4, Instr_ID)
    println("Finished first initialization")
    error2 = OB1_Initialization("01C93357", 4, 4, 4, 4, Instr_ID2)
    println("Finished second initialization")
    Calib = zeros(Float64, 1000)
    Calib2 = zeros(Float64, 1000)
    if pressurepumpflags[3] == 1
        while pressurepumpflags[4] == 0
            println("Turn on vacuum to proceed to calibration")
            sleep(5)
        end
        OB1_Calib(Instr_ID[], Calib, 1000)
        Elveflow_Calibration_Save(
            raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib.txt",
            Calib,
            1000,
        )
        println("Finished first calibration")
        OB1_Calib(Instr_ID2[], Calib2, 1000)
        Elveflow_Calibration_Save(
            raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib2.txt",
            Calib2,
            1000,
        )
        println("Finished second calibration")
    else
        Elveflow_Calibration_Load(
            raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib.txt",
            Calib,
            1000,
        )
        println("Finished loading first calibration")
        Elveflow_Calibration_Load(
            raw"C:\Users\Jeremias\Desktop\Calibjulia\Calib2.txt",
            Calib2,
            1000,
        )
        println("Finished loading second calibration")
    end
    Pressure = Ref{Float64}(0)
    Pressurestoset = Vector{Float64}([0, 0, 0, 0, 0, 0, 0, 0])
    OB1_Set_All_Press(Instr_ID[], Pressurestoset[1:4], Calib, 4, 1000)
    OB1_Set_All_Press(Instr_ID2[], Pressurestoset[5:8], Calib, 4, 1000)
    timetowrite = time()
    while pressurepumpflags[1] == 1
        timetowrite = time()
        readpressure(Instr_ID, Instr_ID2, Calib, Calib2, Pressure, myreadpressure)
        calcsetpressure(
            Pressurestoset,
            myportscaling,
            myoffsetpressure,
            mypressurecruncherarray,
            maxabsp,
        )
        setpressure(Instr_ID, Instr_ID2, Calib, Calib2, Pressurestoset)
        if pressurepumpflags[2] == 1
            writepressure(
                thetopleveldatadir,
                recordfoldernumber,
                timetowrite,
                myreadpressure,
                Pressurestoset,
            )
        end
    end
    OB1_Destructor(Instr_ID[])
    OB1_Destructor(Instr_ID2[])
end

@everywhere function pressformat(x)
    @sprintf("%.13f", x)
end

@everywhere function readpressure(
    Instr_ID,
    Instr_ID2,
    Calib,
    Calib2,
    Pressure,
    myreadpressure,
)
    OB1_Get_Press(Instr_ID[], 1, 1, Calib, Pressure, 1000)
    myreadpressure[1] = Pressure[]
    for port = 2:4
        OB1_Get_Press(Instr_ID[], port, 0, Calib, Pressure, 1000)
        myreadpressure[port] = Pressure[]
    end
    OB1_Get_Press(Instr_ID2[], 1, 1, Calib2, Pressure, 1000)
    myreadpressure[5] = Pressure[]
    for port = 2:4
        OB1_Get_Press(Instr_ID2[], port, 0, Calib2, Pressure, 1000)
        myreadpressure[port+4] = Pressure[]
    end
end

@everywhere function calcsetpressure(
    Pressurestoset,
    myportscaling,
    myoffsetpressure,
    mypressurecruncherarray,
    maxabsp,
)
    @fastmath @inbounds @simd for theport = 1:8
        Pressurestoset[theport] =
            clamp(
                myportscaling[theport] *
                (myoffsetpressure[theport] + mypressurecruncherarray[theport]),
                -maxabsp[1],
                maxabsp[1],
            ) + (rand([-1 1]) * 0.01)#The random term is to compensate for Elveflow poorly stabilizing the pressure
    end
end

@everywhere function setpressure(Instr_ID, Instr_ID2, Calib, Calib2, Pressurestoset)
    OB1_Set_All_Press(Instr_ID[], Pressurestoset[1:4], Calib, 4, 1000)
    OB1_Set_All_Press(Instr_ID2[], Pressurestoset[5:8], Calib2, 4, 1000)
end

@everywhere function writepressure(
    thetopleveldatadir,
    recordfoldernumber,
    timetowrite,
    myreadpressure,
    Pressurestoset,
)
    open(
        thetopleveldatadir * lpad(recordfoldernumber[1], 5, "0") * "/press.csv",
        "a",
    ) do file
        write(
            file,
            @sprintf("%.7f", timetowrite) *
            "," *
            join(pressformat.(myreadpressure), ",") *
            "," *
            join(pressformat.(Pressurestoset), ",") *
            "\n",
        )
    end
end

@everywhere function savebyserial(mypath, myobject)
    open(fid -> serialize(fid, myobject), mypath, "w")
end

@everywhere function openbyserial(mypath)
    open(deserialize, mypath, "r")
end

@everywhere function pointgreycameraconfiguration(cam)
    acquisitionmode!(cam, "Continuous")
    buffermode!(cam, "NewestFirst")
    pixelformat!(cam, "Mono8")
end
@everywhere function saveimage!(
    theimagearray,
    imagefromcamera,
    imid,
    imtimestamp,
    thetopleveldatadir,
    recordfoldernumber,
)
    #jldsave(@sprintf("%.9f",time())*"_"*string(imid)*"_"*string(imtimestamp)*".jld2";theimagearray) #Apparently JLD2 is slow
    copyto!(imagefromcamera, theimagearray)
    savebyserial(
        thetopleveldatadir *
        lpad(recordfoldernumber[1], 5, "0") *
        "/cam0/" *
        @sprintf("%.9f", time()) *
        "_" *
        string(imid) *
        "_" *
        string(imtimestamp) *
        ".slz",
        imagefromcamera,
    ) #Apparently serializing is fast, but it needs an actual array to work with, otherwise serializing will just store what appears to be a pointer to the data in memory, and once the processes have ended then all that goes away.
end

@everywhere function thepointgreycamerafunction(
    theimagearray,
    cameraflags,
    thetopleveldatadir,
    recordfoldernumber,
)
    camlist = CameraList()
    cam = camlist[0]
    pointgreycameraconfiguration(cam)
    runcamera!(cam, cameraflags, theimagearray, thetopleveldatadir, recordfoldernumber)
end

@everywhere function runcamera!(
    cam,
    cameraflags,
    theimagearray,
    thetopleveldatadir,
    recordfoldernumber,
)
    start!(cam)
    println("The camera is starting")
    imagefromcamera = Array{UInt8,2}(undef, 2048, 2048)
    while cameraflags[1] == 1
        imid, imtimestamp, imexposure = getimage!(cam, theimagearray; normalize = false)
        if cameraflags[2] == 1
            saveimage!(
                theimagearray,
                imagefromcamera,
                imid,
                imtimestamp,
                thetopleveldatadir,
                recordfoldernumber,
            )
        end
    end
    println("I'm about to stop the camera")
    stop!(cam)
    println("I've stopped the camera")
end

@everywhere function crunchcustomparser!(
    instructionstring,
    instructionarray,
    landmarksarray,
    customcrunchmetadata,
)
    allthelines = split(instructionstring, "\n")
    for (thelinenumber, theline) in enumerate(allthelines)
        theinstructionelements = split(theline, ";")
        if thelinenumber == 1
            for (theelementnumber, theelement) in enumerate(theinstructionelements)
                landmarksarray[theelementnumber, thelinenumber] =
                    eval(Meta.parse(theelement))
            end
        else
            customcrunchmetadata[1] = thelinenumber - 1
            instructionarray[1, thelinenumber-1] =
                eval(Meta.parse(theinstructionelements[1]))
            if theinstructionelements[2] == "linear"
                instructionarray[2, thelinenumber-1] = 1
            end
            if theinstructionelements[3] == "cart"
                instructionarray[3, thelinenumber-1] = 1
                if theinstructionelements[4] == "diff"
                    instructionarray[4, thelinenumber-1] = 1
                    for item = 5:7
                        instructionarray[item, thelinenumber-1] =
                            eval(Meta.parse(theinstructionelements[item]))
                    end
                elseif theinstructionelements[4] == "point"
                    instructionarray[4, thelinenumber-1] = 2
                    for item = 5:7
                        instructionarray[item, thelinenumber-1] =
                            eval(Meta.parse(theinstructionelements[item]))
                    end
                end
            elseif theinstructionelements[3] == "cyl"
                instructionarray[3, thelinenumber-1] = 2
                if theinstructionelements[4] == "phase"
                    instructionarray[4, thelinenumber-1] = 1
                    if theinstructionelements[5] == "z"
                        instructionarray[5, thelinenumber-1] = 3
                        for item = 6:8
                            instructionarray[item, thelinenumber-1] =
                                eval(Meta.parse(theinstructionelements[item]))
                        end
                    end
                elseif theinstructionelements[4] == "radius"
                    instructionarray[4, thelinenumber-1] = 2
                    if theinstructionelements[5] == "dim"
                        instructionarray[5, thelinenumber-1] = 1
                        if theinstructionelements[6] == "z"
                            instructionarray[6, thelinenumber-1] = 3
                            if theinstructionelements[7] == "x"
                                instructionarray[7, thelinenumber-1] = 1
                                for item = 8:9
                                    instructionarray[item, thelinenumber-1] =
                                        eval(Meta.parse(theinstructionelements[item]))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

@everywhere function crunchcustomportparser!(
    instructionstring,
    instructionportarray,
    landmarksportarray,
    customportcrunchmetadata,
)
    allthelines = split(instructionstring, "\n")
    for (thelinenumber, theline) in enumerate(allthelines)
        theinstructionelements = split(theline, ";")
        if thelinenumber == 1
            for (theelementnumber, theelement) in enumerate(theinstructionelements)
                landmarksportarray[theelementnumber, thelinenumber] =
                    eval(Meta.parse(theelement))
            end
        else
            customportcrunchmetadata[1] = thelinenumber - 1
            instructionportarray[1, thelinenumber-1] =
                eval(Meta.parse(theinstructionelements[1]))
            if theinstructionelements[2] == "block"
                instructionportarray[2, thelinenumber-1] = 1
            end
            if theinstructionelements[3] == "cart"
                instructionportarray[3, thelinenumber-1] = 1
                if theinstructionelements[4] == "point"
                    instructionportarray[4, thelinenumber-1] = 2
                    for item = 5:12
                        instructionportarray[item, thelinenumber-1] =
                            eval(Meta.parse(theinstructionelements[item]))
                    end
                end
            end
        end
    end
end

@everywhere function thestagefunction!(myflags, myreadstage, mysetstage)
    ret = PriorScientificSDK_Initialise()
    println(ret)
    rx = Array{UInt8}(undef, 1000)
    ret = PriorScientificSDK_Version(rx)
    returnedstring = String(rx[firstindex(rx):findfirst(x -> x == 0x00, rx)-1])
    println(returnedstring)
    sessionID = PriorScientificSDK_OpenNewSession()
    println(sessionID)
    ret = PriorScientificSDK_cmd(sessionID, "dll.apitest 33 goodresponse", rx)
    returnedstring = String(rx[firstindex(rx):findfirst(x -> x == 0x00, rx)-1])
    println(returnedstring)
    ret = PriorScientificSDK_cmd(sessionID, "controller.connect 3", rx)
    returnedstring = String(rx[firstindex(rx):findfirst(x -> x == 0x00, rx)-1])
    println(returnedstring)

    while myflags[8] == 1
        ret = PriorScientificSDK_cmd(sessionID, "controller.stage.position.get", rx)
        returnedstring = String(rx[firstindex(rx):findfirst(x -> x == 0x00, rx)-1])
        myreadstage .= parse.(Int, split(returnedstring, ","))
        if myflags[9] == 1
            ret = PriorScientificSDK_cmd(
                sessionID,
                "controller.stage.goto-position $(mysetstage[1]) $(mysetstage[2])",
                rx,
            )
            sleep(0.1)
        end
    end

    println("I'm about to stop the stage")
    ret = PriorScientificSDK_cmd(sessionID, "controller.disconnect", rx)
    println("I've stopped the stage")
end

@everywhere function squishanddisplay(theimagearray, myflags, squishparameters)
    gpuarraystack = CuArray{UInt8}(undef, Int(floor(squishparameters[1])), 2048, 2048)
    gpuarraystack .= 0
    mysquishedframe = zeros(UInt8, (2048, 2048))
    framenumber = 1

    img = Observable(mysquishedframe)
    imgplot = image(
        img,
        axis = (aspect = DataAspect(),),
        figure = (figure_padding = 0, size = (600, 600)),
    )
    hidedecorations!(imgplot.axis)
    display(imgplot)
    oldframemax = squishparameters[1]

    camholder = Array{UInt8,2}(undef, 2048, 2048)
    gpuholder = CuArray{UInt8}(undef, 2048, 2048)
    while myflags[13] == 1
        if oldframemax != squishparameters[1]
            gpuarraystack =
                CuArray{UInt8}(undef, Int(floor(squishparameters[1])), 2048, 2048)
            gpuarraystack .= 0
            framenumber = 1
        end
        camholder .= theimagearray #For whatever reason, the copyto! command sees direct copying from a SharedArray as a scalar operation, so this is an intermediate. It has a small performance hit. A bug report has been filed https://github.com/JuliaGPU/CUDA.jl/issues/2317
        copyto!(gpuholder, camholder)
        gpuarraystack[framenumber, :, :] .= gpuholder
        copyto!(mysquishedframe, maximum(gpuarraystack, dims = 1)[1, :, :])#This eats up GPU memory like crazy because maximum does internal allocations. Surprisingly maximum! which doesn't use allocations performs worse (about half as fast), though presumably when garbage collection comes knocking that advantage is thrown out. For now we use maximum until something else needs GPU memory to work.
        img[] = mysquishedframe
        sleep(squishparameters[2])
        if framenumber == squishparameters[1]
            framenumber = 1
        else
            framenumber += 1
        end
    end
    println("I'm ending my image squish loop")
end

@everywhere function custompathplotter(
    landmarksarray,
    customcrunchmetadata,
    instructionarray,
)
    timerange = 1:200
    mytimepoints = (landmarksarray[1, customcrunchmetadata[1]+1] / 200) * collect(timerange)
    mypositionpoints = Array{Float64,2}(undef, 3, length(timerange))
    thefancypantspos = MVector{3,Float64}(0, 0, 0)
    thefancypantsarray = MVector{6,Float64}(0, 0, 0, 0, 0, 0)
    @fastmath @inbounds for timeindex ∈ timerange
        thefancypants!(
            mytimepoints[timeindex] % landmarksarray[1, customcrunchmetadata[1]+1],
            thefancypantsarray,
            instructionarray,
            landmarksarray,
            thefancypantspos,
            [0],
        )
        @simd for thepos ∈ 1:3
            mypositionpoints[thepos, timeindex] = thefancypantspos[thepos]
        end
    end
    pathgenplot = scatter(
        mypositionpoints[1, :],
        mypositionpoints[2, :],
        mypositionpoints[3, :],
        color = timerange,
        colormap = :rainbow,
    )
    display(pathgenplot)
end

@everywhere function drainprocessstack!(stack)
    while !isempty(stack)
        fetch(pop!(stack))
    end
end

function slztopgm(mytoppath)
    slzfiles = glob(glob"*.slz", mytoppath)
    @showprogress "Saving images" for myslzfile in slzfiles
        Images.save(
            dirname(myslzfile) * splitext(basename(myslzfile))[1] * ".pgm",
            openbyserial(myslzfile),
        )
    end
end

function mpmodularstart()
    println("Starting mpmodular")
    myreadpressure = SharedVector{Float64}(8)
    myoffsetpressure = SharedVector{Float64}(8)
    myportscaling = SharedVector{Float64}(8)
    myportscaling .= 1.00
    mypressurecruncherarray = SharedArray{Float64}(8)
    mymodeamounts = SharedVector{Float64}(6)
    mymodescalingamounts = SharedVector{Float64}(3)
    myportassignments = SharedVector{Int}(8)
    maxabsp = SharedVector{Float64}(1)
    pressurepumpflags = SharedVector{UInt8}(4)
    pressurepumpflags .= 0

    combinedcrunchmodeamounts = SharedVector{Float64}(6)
    instructionarray = SharedArray{Float64}((10, 100))
    landmarksarray = SharedArray{Float64}((4, 100))
    customcrunchmetadata = SharedVector{Int}(1)

    instructionportarray = SharedArray{Float64}((12, 100))
    landmarksportarray = SharedArray{Float64}((4, 100))
    customportcrunchmetadata = SharedVector{Int}(1)

    cameraflags = SharedVector{UInt8}(2)
    cameraflags .= 0
    cameraimagesharedarrays = Vector()
    theimagearray = SharedArray{UInt8}((2048, 2048))

    myflags = SharedVector{UInt8}(13)

    r = SharedVector{Int}(2)
    r .= [1024, 1024]
    dest = SharedVector{Int}(3)
    dest .= [1024, 1024, 0]
    clickedlocation = SharedVector{Int}(2)
    clickedlocation .= 0
    trackplanescale = SharedVector{Float64}(2)
    trackplanescale .= 1.00
    custommodescale = SharedVector{Float64}(1)
    custommodescale .= 1.00
    customportscale = SharedVector{Float64}(1)
    customportscale .= 1.00
    imageanalysisparameters = SharedVector{Float64}(4)
    imageanalysisparameters .= [128.0, 128.0, 100.0, 3.0]
    trackcoords = SharedVector{Int}(2)
    trackcoords[1] = 2
    trackcoords[2] = 1

    myreadstage = SharedVector{Int}(2)
    mysetstage = SharedVector{Int}(2)

    squishparameters = SharedVector{Float64}(2)
    squishparameters .= [50, 0]

    pumpfutures = Vector()
    crunchfutures = Vector()
    camerafutures = Vector()
    displayfutures = Vector()
    trackerfutures = Vector()
    stagefutures = Vector()
    squishdispfutures = Vector()
    oldpumpstate = 0
    oldcrunchstate = 0
    oldcrunchcustomstate = 0
    oldcamstate = 0
    olddispstate = 0
    oldrecordstate = 0
    #oldtextcustom=""
    oldtrackerstate = 0
    oldstagestate = 0
    oldsquishdispstate = 0

    w = Window()
    oldcrunchcustomportstate = 0
    println("Opened window")
    #load!(w,"mpcamtrack.html")
    title(w, "Julia mpcamtrack")
    f = open("C:/Users/Jeremias/gitrepos/mpcamtrackjulia/mpcamtrack.html") do file
        read(file, String)
    end
    body!(w, f, async = false)
    println("Finished reading file")
    #loadhtml(w,f)
    println("HTML is loaded")

    thetopleveldatadir =
        raw"C:/Users/Jeremias/Desktop/recordeddata" *
        Dates.format(Dates.now(), "yyyymmddHHMMSS") *
        "/"
    recordfoldernumber = SharedVector{Int}(1)
    recordfoldernumber .= 0

    while active(w)
        pressurestringholder = Printf.format.(Ref(Printf.Format("%.2f")), myreadpressure)
        js(
            w,
            Blink.JSString(
                """document.getElementById("lp1").innerHTML="$(pressurestringholder[1])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("lp2").innerHTML="$(pressurestringholder[2])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("lp3").innerHTML="$(pressurestringholder[3])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("lp4").innerHTML="$(pressurestringholder[4])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("rp1").innerHTML="$(pressurestringholder[5])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("rp2").innerHTML="$(pressurestringholder[6])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("rp3").innerHTML="$(pressurestringholder[7])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("rp4").innerHTML="$(pressurestringholder[8])" """,
            ),
        )

        combinedcrunchmodestringholder =
            Printf.format.(Ref(Printf.Format("%.2f")), combinedcrunchmodeamounts)
        js(
            w,
            Blink.JSString(
                """document.getElementById("finalxam").innerHTML="$(combinedcrunchmodestringholder[1])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("finalyam").innerHTML="$(combinedcrunchmodestringholder[2])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("finalzam").innerHTML="$(combinedcrunchmodestringholder[3])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("finalbam").innerHTML="$(combinedcrunchmodestringholder[4])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("finalopxam").innerHTML="$(combinedcrunchmodestringholder[5])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("finalopyam").innerHTML="$(combinedcrunchmodestringholder[6])" """,
            ),
        )

        myoffsetpressure[1] =
            js(w, Blink.JSString("""document.getElementById("lpb1sl").valueAsNumber"""))
        myoffsetpressure[2] =
            js(w, Blink.JSString("""document.getElementById("lpb2sl").valueAsNumber"""))
        myoffsetpressure[3] =
            js(w, Blink.JSString("""document.getElementById("lpb3sl").valueAsNumber"""))
        myoffsetpressure[4] =
            js(w, Blink.JSString("""document.getElementById("lpb4sl").valueAsNumber"""))
        myoffsetpressure[5] =
            js(w, Blink.JSString("""document.getElementById("rpb1sl").valueAsNumber"""))
        myoffsetpressure[6] =
            js(w, Blink.JSString("""document.getElementById("rpb2sl").valueAsNumber"""))
        myoffsetpressure[7] =
            js(w, Blink.JSString("""document.getElementById("rpb3sl").valueAsNumber"""))
        myoffsetpressure[8] =
            js(w, Blink.JSString("""document.getElementById("rpb4sl").valueAsNumber"""))

        myportscaling[1] =
            js(w, Blink.JSString("""document.getElementById("lpb1ssl").valueAsNumber"""))
        myportscaling[2] =
            js(w, Blink.JSString("""document.getElementById("lpb2ssl").valueAsNumber"""))
        myportscaling[3] =
            js(w, Blink.JSString("""document.getElementById("lpb3ssl").valueAsNumber"""))
        myportscaling[4] =
            js(w, Blink.JSString("""document.getElementById("lpb4ssl").valueAsNumber"""))
        myportscaling[5] =
            js(w, Blink.JSString("""document.getElementById("rpb1ssl").valueAsNumber"""))
        myportscaling[6] =
            js(w, Blink.JSString("""document.getElementById("rpb2ssl").valueAsNumber"""))
        myportscaling[7] =
            js(w, Blink.JSString("""document.getElementById("rpb3ssl").valueAsNumber"""))
        myportscaling[8] =
            js(w, Blink.JSString("""document.getElementById("rpb4ssl").valueAsNumber"""))

        mymodeamounts[1] =
            js(w, Blink.JSString("""document.getElementById("xmodesl").valueAsNumber"""))
        mymodeamounts[2] =
            js(w, Blink.JSString("""document.getElementById("ymodesl").valueAsNumber"""))
        mymodeamounts[3] =
            js(w, Blink.JSString("""document.getElementById("zmodesl").valueAsNumber"""))
        mymodeamounts[4] =
            js(w, Blink.JSString("""document.getElementById("bmodesl").valueAsNumber"""))
        mymodeamounts[5] =
            js(w, Blink.JSString("""document.getElementById("opxmodesl").valueAsNumber"""))
        mymodeamounts[6] =
            js(w, Blink.JSString("""document.getElementById("opymodesl").valueAsNumber"""))

        mymodescalingamounts[1] = js(
            w,
            Blink.JSString("""document.getElementById("xmodescalesl").valueAsNumber"""),
        )
        mymodescalingamounts[2] = js(
            w,
            Blink.JSString("""document.getElementById("ymodescalesl").valueAsNumber"""),
        )
        mymodescalingamounts[3] = js(
            w,
            Blink.JSString("""document.getElementById("zmodescalesl").valueAsNumber"""),
        )

        pressurepumpflags[1] =
            js(w, Blink.JSString("""document.getElementById("pumpon").checked"""))
        pressurepumpflags[3] =
            js(w, Blink.JSString("""document.getElementById("calibon").checked"""))
        pressurepumpflags[4] =
            js(w, Blink.JSString("""document.getElementById("calibready").checked"""))

        mycurrentcrunchstate =
            js(w, Blink.JSString("""document.getElementById("crunchon").checked"""))
        mycurrentcrunchcustomstate =
            js(w, Blink.JSString("""document.getElementById("crunchcustomon").checked"""))
        mycurrentcrunchcustomportstate = js(
            w,
            Blink.JSString("""document.getElementById("crunchcustomporton").checked"""),
        )
        mycurrentcamstate =
            js(w, Blink.JSString("""document.getElementById("camon").checked"""))
        mycurrentdispstate =
            js(w, Blink.JSString("""document.getElementById("displayon").checked"""))
        mycurrentrecordingstate =
            js(w, Blink.JSString("""document.getElementById("recordon").checked"""))
        mycurrenttrackingstate =
            js(w, Blink.JSString("""document.getElementById("trackon").checked"""))
        mycurrenttextcustom =
            js(w, Blink.JSString("""document.getElementById("mytextcustom").value"""))
        mycurrenttextcustomport =
            js(w, Blink.JSString("""document.getElementById("mytextcustomport").value"""))
        mycurrentstagestate =
            js(w, Blink.JSString("""document.getElementById("stageon").checked"""))
        mycurrentstageupdatestate =
            js(w, Blink.JSString("""document.getElementById("stageupdateon").checked"""))
        mycurrenttrackbestguessstate =
            js(w, Blink.JSString("""document.getElementById("trackbestguesson").checked"""))
        mycurrentsquishdispstate =
            js(w, Blink.JSString("""document.getElementById("squishdisplayon").checked"""))
        mycurrentexperimentalnotes =
            js(w, Blink.JSString("""document.getElementById("experimentalnotes").value"""))

        custommodescale[1] = js(
            w,
            Blink.JSString(
                """document.getElementById("custommodescalesl").valueAsNumber""",
            ),
        )
        customportscale[1] = js(
            w,
            Blink.JSString(
                """document.getElementById("customportscalesl").valueAsNumber""",
            ),
        )

        myportassignments[1] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portl1box").value""")),
        )
        myportassignments[2] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portl2box").value""")),
        )
        myportassignments[3] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portl3box").value""")),
        )
        myportassignments[4] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portl4box").value""")),
        )
        myportassignments[5] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portr1box").value""")),
        )
        myportassignments[6] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portr2box").value""")),
        )
        myportassignments[7] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portr3box").value""")),
        )
        myportassignments[8] = parse(
            Int,
            js(w, Blink.JSString("""document.getElementById("portr4box").value""")),
        )

        maxabsp[1] =
            js(w, Blink.JSString("""document.getElementById("maxabspsl").valueAsNumber"""))

        stagereadstringholder = Printf.format.(Ref(Printf.Format("%.2f")), myreadstage)
        js(
            w,
            Blink.JSString(
                """document.getElementById("sxr").innerHTML="$(stagereadstringholder[1])" """,
            ),
        )
        js(
            w,
            Blink.JSString(
                """document.getElementById("syr").innerHTML="$(stagereadstringholder[2])" """,
            ),
        )

        trackplanescale[1] = js(
            w,
            Blink.JSString(
                """document.getElementById("trackplanescalexsl").valueAsNumber""",
            ),
        )
        trackplanescale[2] = js(
            w,
            Blink.JSString(
                """document.getElementById("trackplanescaleysl").valueAsNumber""",
            ),
        )
        imageanalysisparameters[1] = js(
            w,
            Blink.JSString("""document.getElementById("clipsizeisl").valueAsNumber"""),
        )
        imageanalysisparameters[2] = js(
            w,
            Blink.JSString("""document.getElementById("clipsizejsl").valueAsNumber"""),
        )
        imageanalysisparameters[3] = js(
            w,
            Blink.JSString(
                """document.getElementById("imageanalysisthresholdsl").valueAsNumber""",
            ),
        )
        imageanalysisparameters[4] = js(
            w,
            Blink.JSString(
                """document.getElementById("kernelparametersl").valueAsNumber""",
            ),
        )
        mycurrenttrackcoordstate =
            js(w, Blink.JSString("""document.getElementById("trackxy").checked"""))

        squishparameters[1] = js(
            w,
            Blink.JSString(
                """document.getElementById("squishstacksizesl").valueAsNumber""",
            ),
        )
        squishparameters[2] = js(
            w,
            Blink.JSString("""document.getElementById("squishdelaysl").valueAsNumber"""),
        )

        if (pressurepumpflags[1] == 1) && (oldpumpstate == 0)
            println("I'm about to start the new pump process")
            push!(
                pumpfutures,
                @spawnat :any theelveflowfunction(
                    pressurepumpflags,
                    myreadpressure,
                    mypressurecruncherarray,
                    myoffsetpressure,
                    maxabsp,
                    myportscaling,
                    thetopleveldatadir,
                    recordfoldernumber,
                )
            )
            println("I've started the new pump process")
            oldpumpstate = 1
        elseif (pressurepumpflags[1] == 0) && (oldpumpstate == 1)
            println("I'm fetching the new pump process")
            fetch(pop!(pumpfutures))
            println("I've fetched the new pump process")
            oldpumpstate = 0
        end
        if (mycurrentcrunchstate) && (oldcrunchstate == 0)
            println("I'm about to start the new crunch process")
            myflags[5] = 1
            push!(
                crunchfutures,
                @spawnat :any thepressurecruncher(
                    myflags,
                    mypressurecruncherarray,
                    mymodeamounts,
                    mymodescalingamounts,
                    myportassignments,
                    combinedcrunchmodeamounts,
                    landmarksarray,
                    instructionarray,
                    customcrunchmetadata,
                    r,
                    trackplanescale,
                    custommodescale,
                    customportscale,
                    instructionportarray,
                    landmarksportarray,
                    customportcrunchmetadata,
                    trackcoords,
                    dest,
                )
            )
            println("I've started the new crunch process")
            oldcrunchstate = 1
        elseif (!mycurrentcrunchstate) && (oldcrunchstate == 1)
            myflags[5] = 0
            println("I'm fetching the new crunch process")
            fetch(pop!(crunchfutures))
            println("I've fetched the new crunch process")
            oldcrunchstate = 0
        end
        if (mycurrentcrunchcustomstate) && (oldcrunchcustomstate == 0)
            println("I'm about to set up custom crunching")
            @fastmath @inbounds @simd for myidx in eachindex(instructionarray)
                instructionarray[myidx] = 0
            end
            @fastmath @inbounds @simd for myidx in eachindex(landmarksarray)
                landmarksarray[myidx] = 0
            end
            crunchcustomparser!(
                mycurrenttextcustom,
                instructionarray,
                landmarksarray,
                customcrunchmetadata,
            )
            fancypantslandmarks!(instructionarray, landmarksarray, customcrunchmetadata)
            custompathplotter(landmarksarray, customcrunchmetadata, instructionarray)
            myflags[7] = 1
            println("I've set up custom crunching")
            oldcrunchcustomstate = 1
        elseif (!mycurrentcrunchcustomstate) && (oldcrunchcustomstate == 1)
            println("I'm stopping custom crunching")
            myflags[7] = 0
            oldcrunchcustomstate = 0
            println("I've stopped custom crunching")
        end
        if (mycurrentcrunchcustomportstate) && (oldcrunchcustomportstate == 0)
            println("I'm about to set up custom port crunching")
            @fastmath @inbounds @simd for myidx in eachindex(instructionportarray)
                instructionportarray[myidx] = 0
            end
            @fastmath @inbounds @simd for myidx in eachindex(landmarksportarray)
                landmarksportarray[myidx] = 0
            end
            crunchcustomportparser!(
                mycurrenttextcustomport,
                instructionportarray,
                landmarksportarray,
                customportcrunchmetadata,
            )
            fancypantslandmarksport!(
                instructionportarray,
                landmarksportarray,
                customportcrunchmetadata,
            )
            myflags[11] = 1
            println("I've set up custom port crunching")
            oldcrunchcustomportstate = 1
        elseif (!mycurrentcrunchcustomportstate) && (oldcrunchcustomportstate == 1)
            println("I'm about to stop custom port crunching")
            myflags[11] = 0
            oldcrunchcustomportstate = 0
            println("I've stopped custom port crunching")
        end
        if (mycurrentcamstate) && (oldcamstate == 0)
            println("I'm about to start the new cam process")
            cameraflags[1] = 1
            push!(
                camerafutures,
                @spawnat :any thepointgreycamerafunction(
                    theimagearray,
                    cameraflags,
                    thetopleveldatadir,
                    recordfoldernumber,
                )
            )
            println("I've started the new cam process")
            oldcamstate = 1
        elseif (!mycurrentcamstate) && (oldcamstate == 1)
            cameraflags[1] = 0
            println("I'm fetching the new cam process")
            fetch(pop!(camerafutures))
            println("I've fetched the new cam process")
            oldcamstate = 0
        end
        if (mycurrentdispstate) && (olddispstate == 0)
            println("I'm about to start the new disp process")
            myflags[3] = 1
            push!(
                displayfutures,
                @spawnat :any thedisplayfunction(
                    theimagearray,
                    myflags,
                    clickedlocation,
                    r,
                    imageanalysisparameters,
                    dest,
                )
            )
            println("I've started the new disp process")
            olddispstate = 1
        elseif (!mycurrentdispstate) && (olddispstate == 1)
            myflags[3] = 0
            println("I'm fetching the new disp process")
            fetch(pop!(displayfutures))
            println("I've fetched the new disp process")
            olddispstate = 0
        end
        if (mycurrentrecordingstate) && (oldrecordstate == 0)
            databatchpath = thetopleveldatadir * lpad(recordfoldernumber[1], 5, "0")
            mkpath(databatchpath * "/cam0/")
            open(databatchpath * "/experimentalnotes.txt", "a") do file
                write(file, mycurrentexperimentalnotes)
            end
            pressurepumpflags[2] = 1
            cameraflags[2] = 1
            oldrecordstate = 1
        elseif (!mycurrentrecordingstate) && (oldrecordstate == 1)
            pressurepumpflags[2] = 0
            cameraflags[2] = 0
            oldrecordstate = 0
            recordfoldernumber[1] += 1
        end
        if (mycurrenttrackingstate) && (oldtrackerstate == 0)
            println("I'm about to start the new tracking process")
            myflags[6] = 1
            push!(
                trackerfutures,
                @spawnat :any thetrackerfunction!(
                    theimagearray,
                    myflags,
                    r,
                    clickedlocation,
                    imageanalysisparameters,
                )
            )
            oldtrackerstate = 1
        elseif (!mycurrenttrackingstate) && (oldtrackerstate == 1)
            myflags[6] = 0
            println("I'm fetching the new tracking process")
            fetch(pop!(trackerfutures))
            println("I've fetched the new tracking process")
            oldtrackerstate = 0
        end
        if (mycurrentstagestate) && (oldstagestate == 0)
            println("I'm about to start the new stage process")
            myflags[8] = 1
            push!(
                stagefutures,
                @spawnat :any thestagefunction!(myflags, myreadstage, mysetstage)
            )
            println("I've started the new stage process")
            oldstagestate = 1
        elseif (!mycurrentstagestate) && (oldstagestate == 1)
            myflags[8] = 0
            println("I'm fetching the new stage process")
            fetch(pop!(stagefutures))
            println("I've fetched the new stage process")
            oldstagestate = 0
        end
        if mycurrentstageupdatestate
            mysetstage[1] = parse(
                Int,
                js(w, Blink.JSString("""document.getElementById("sxs").value""")),
            )
            mysetstage[2] = parse(
                Int,
                js(w, Blink.JSString("""document.getElementById("sys").value""")),
            )
            myflags[9] = 1
        else
            myflags[9] = 0
        end
        if mycurrenttrackbestguessstate
            myflags[10] = 1
        else
            myflags[10] = 0
        end
        if (mycurrentsquishdispstate) && (oldsquishdispstate == 0)
            println("I'm about to start the new squish disp process")
            myflags[13] = 1
            push!(
                squishdispfutures,
                @spawnat :any squishanddisplay(theimagearray, myflags, squishparameters)
            )
            println("I've started the new squish disp process")
            oldsquishdispstate = 1
        elseif (!mycurrentsquishdispstate) && (oldsquishdispstate == 1)
            myflags[13] = 0
            println("I'm fetching the new squish disp process")
            fetch(pop!(squishdispfutures))
            println("I've fetched the new squish disp process")
            oldsquishdispstate = 0
        end
        if mycurrenttrackcoordstate == 0
            trackcoords[1] = 2
            trackcoords[2] = 1
        else
            trackcoords[1] = 1
            trackcoords[2] = 2
        end
        sleep(0.1)
    end

    myflags .= 0
    pressurepumpflags .= 0
    cameraflags .= 0

    drainprocessstack!(pumpfutures)
    drainprocessstack!(crunchfutures)
    drainprocessstack!(camerafutures)
    drainprocessstack!(displayfutures)
    drainprocessstack!(trackerfutures)
    drainprocessstack!(stagefutures)

    println("Closing mpmodular")
end
