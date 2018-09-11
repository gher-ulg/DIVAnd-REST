using Test
import HTTP
import JSON
import DIVAnd
using NCDatasets
using DataStructures
using Random
using Statistics
using OceanPlot
using PyPlot

include("webdav.jl")

const EXTERNAL_HOST = get(ENV,"DIVAND_EXTERNAL_HOST","127.0.0.1")
const EXTERNAL_MOUNTPOINT = get(ENV,"DIVAND_EXTERNAL_MOUNTPOINT","/")
const EXTERNAL_PORT = parse(Int,get(ENV,"DIVAND_EXTERNAL_PORT","8002"))
const port = parse(Int,get(ENV,"DIVAND_PORT","8001"))
const workdir = get(ENV,"DIVAND_WORKDIR",tempdir())
const baseurl = get(ENV,"DIVAND_EXTERNAL_BASEURL","http://$(EXTERNAL_HOST):$(EXTERNAL_PORT)/")

# Version of the REST API
const version = "v1"

# for example /v1
const basedir = "/$(version)"

# for example DIVAnd/v1
const external_basedir = "$(EXTERNAL_MOUNTPOINT)$(version)"

const idlength = 24

DIVAnd_tasks = Dict{String,Any}()
DIVAnd_tasks_status = Dict{String,Any}()

const bathdatasets = Dict{String,Tuple{String,Bool}}(
    "GEBCO" => ("data/gebco_30sec_16.nc",true))


const datalist = Dict{String,String}(
    "WOD-Salinity" => "data/WOD-Salinity.nc",
    "gebco_30sec_16" => "data/gebco_30sec_16.nc"
)



"""
   strbbox = encodebbox(bbox)
   minlon,minlat,maxlon,maxlat
"""
encodebbox(bbox) = join(bbox,",")
decodebbox(strbbox) = parse.(Float64,split(strbbox,","))

encodelist(list) = join(list,",")
decodelist(strlist) = parse.(Float64,split(strlist,","))




function savebathnc(filename,b,xy)
    x,y = xy
    ds = Dataset(filename,"c")
    # Dimensions

    ds.dim["lat"] = size(b,2)
    ds.dim["lon"] = size(b,1)

    # Declare variables

    nclat = defVar(ds,"lat", Float64, ("lat",))
    nclat.attrib["long_name"] = "Latitude"
    nclat.attrib["standard_name"] = "latitude"
    nclat.attrib["units"] = "degrees_north"

    nclon = defVar(ds,"lon", Float64, ("lon",))
    nclon.attrib["long_name"] = "Longitude"
    nclon.attrib["standard_name"] = "longitude"
    nclon.attrib["units"] = "degrees_east"

    ncbat = defVar(ds,"bat", Float32, ("lon", "lat"))
    ncbat.attrib["long_name"] = "elevation above sea level"
    ncbat.attrib["standard_name"] = "height"
    ncbat.attrib["units"] = "meters"

    # Global attributes

    #ds.attrib["title"] = "GEBCO"

    # Define variables

    nclon[:] = x
    nclat[:] = y
    ncbat[:] = b

    close(ds)
end



function resolvedata(url)
    if startswith(url,"sampledata:")
        name = split(url,"data:")[2]
        return get(datalist,name,nothing)
    elseif (startswith(url,"http:") || startswith(url,"https:") ||
            startswith(url,"ftp:"))

        tmpfname = joinpath(workdir,string(hash(url)))

        if isfile(tmpfname)
            @debug "use $(url) from cache $(tmpfname)"
            return tmpfname
        else
            try
                Base.download(url,tmpfname)
                return tmpfname
            catch
                @info "download failed: $(url)"
                return nothing
            end
        end
    else
        error("URI scheme is not allowed $(url)")
    end
end

function analysis_wrapper(data,filename,channel)
    @debug "analysis_wrapper"
    minlon,minlat,maxlon,maxlat = data["bbox"]
    Δlon,Δlat = data["resolution"]

    lonr = minlon:Δlon:maxlon
    latr = minlat:Δlat:maxlat

    @debug "analysis_wrapper1"
    bathname = resolvedata(data["bathymetry"])
    bathisglobal = get(data,"bathymetryisglobal",true)

    varname = data["varname"]

    obsname = resolvedata(data["observations"])
    epsilon2 = data["epsilon2"]

    # fixme just take one
    value,lon,lat,depth,obstime,ids = DIVAnd.loadobs(Float64,obsname,varname)
    depthr = data["depth"]


    @debug "analysis_wrapper2"
    DIVAnd.checkobs((lon,lat,depth,obstime),value,ids)

    sz = (length(lonr),length(latr),length(depthr))

    lenx = fill(data["len"][1],sz)
    leny = fill(data["len"][2],sz)
    lenz = [10+depthr[k]/15 for i = 1:sz[1], j = 1:sz[2], k = 1:sz[3]]

    @show mean(lenz)
    years = [data["years"][1]:data["years"][2]]


    # winter: January-March    1,2,3
    # spring: April-June       4,5,6
    # summer: July-September   7,8,9
    # autumn: October-December 10,11,12

    monthlist = data["monthlist"]


    #TS = DIVAnd.TimeSelectorYW(years,year_window,monthlist)
    TS = DIVAnd.TimeSelectorYearListMonthList(years,monthlist)

    # use all keys with the metadata_ prefix
    metadata = Dict((replace(k,r"^metadata_" => ""),v)
                    for (k,v) in data if startswith(k,"metadata_"))
    @show metadata

    ncglobalattrib,ncvarattrib =
        #debug
        #if length(metadata) > 0
        if false
            DIVAnd.SDNMetadata(metadata,filename,varname,lonr,latr)
        else
            Dict{String,String}(),Dict{String,String}()
        end

    if isfile(filename)
       rm(filename) # delete the previous analysis
    end

    memtofit = 10
    function plotres(timeindex,sel,fit,erri)
        @show timeindex
        push!(channel,"time index $(timeindex)")
    end

    @time res = DIVAnd.diva3d(
        (lonr,latr,depthr,TS),
        (lon,lat,depth,obstime),
        value,
        (lenx,leny,lenz),
        epsilon2,
        filename,varname,
        bathname = bathname,
        bathisglobal = bathisglobal,
        ncvarattrib = ncvarattrib,
        ncglobalattrib = ncglobalattrib,
        memtofit = memtofit,
        plotres = plotres
    )

    DIVAnd.saveobs(filename,(lon,lat,depth,obstime),ids)
end


analysisname(analysisid) = joinpath(workdir,analysisid * ".nc")



router = HTTP.Router()

function sendfile_default(code,filename,headers = [])
    f = open(filename)
    data = read(f)
    @show length(data)
    close(f)

    return HTTP.Response(code,data,headers,headers = [])
end

function sendfile_mmap(code,filename)
    @show "mmap",filename
    data = Mmap.mmap(open(filename), Array{UInt8,1})
    return HTTP.Response(code,data,headers)
end

function sendfile_nginx(code,filename,headers = [])
    @show "nginx fname",filename
    return HTTP.Response(
        code,
        ["X-Accel-Redirect" => filename, headers...]);

end

sendfile = sendfile_nginx
#sendfile = sendfile_mmap
#sendfile = sendfile_default

function bathymetry(req::HTTP.Request)
    params = HTTP.queryparams(HTTP.URI(req.target))
    @show params
    minlon,minlat,maxlon,maxlat = decodebbox(params["bbox"])
    reslon,reslat = decodelist(params["resolution"])
    dataset = params["dataset"]


    bathname,isglobal = bathdatasets[dataset]

    xi,yi,bath = DIVAnd.load_bath(bathname,isglobal,minlon:reslon:maxlon,minlat:reslat:maxlat)

    @show minlon,minlat,maxlon,maxlat
    @show reslon,reslat
    @show xi
    filename = tempname()
    #filename = "/tmp/tmp2.nc"
    #if isfile(filename)
    #    rm(filename)
    #end
    savebathnc(filename,bath,(xi,yi))

    return sendfile(200,filename, [
        "Content-Type" => "application/netcdf",
        "Content-Disposition" => "attachment; filename=\"bathymetry.nc\""])

    #stream = HTTP.stream(open(filename))
    #HTTP.Response(200,"Hi")
    #return HTTP.Response(200,stream)
    #return HTTP.Stream(HTTP.Response(200),open("test.txt"))
end


function options_analysis(req::HTTP.Request)

    return HTTP.Response(
        200,
    ["Access-Control-Allow-Origin" => "*",
     "Access-Control-Allow-Methods" =>  "GET, POST, PUT",
     "Access-Control-Allow-Headers" => "Content-Type"
     ])

end

function analysis(req::HTTP.Request)
    path = HTTP.URI(req.target).path

    if req.method == "POST"
        data = JSON.parse(
            HTTP.payload(req,String);
            dicttype=DataStructures.OrderedDict)

        observations = data["observations"]

        @show path
        analysisid = randstring(idlength)
        #analysisid = "12345"

        channel = Channel(Inf)

        @async begin
            push!(channel,"a")
            println("request analysis")
            fname = analysisname(analysisid)
            if isfile(fname)
                rm(fname)
            end
            #sleep(5.0)

            push!(channel,"b")
            println("request analysis 2")
            analysis_wrapper(data,fname * ".temp",channel)
            println("request analysis 3")
            mv(fname * ".temp",fname)
            #f = open(fname,"w")
            #write(f,"lala123")
            #close(f)
            push!(channel,"done")
        end

        DIVAnd_tasks[analysisid] = channel
        DIVAnd_tasks_status[analysisid] = "started"
        println("request analysis 4")

        # analysis in progress
        return HTTP.Response(202,["Location" => "$(basedir)/queue/$(analysisid)"])
        #return HTTP.Response(202,["Location" => "$(basedir)/queue/"])
    else
        # analysis is done
        analysisid = split(path,"$(basedir)/analysis/")[2]
        fname = analysisname(analysisid)
        if isfile(fname)
            return sendfile(200,fname, [
                "Content-Type" => "application/netcdf",
                "Content-Disposition" => "attachment; filename=\"DIVAnd-analysis.nc\""])
        else
            return HTTP.Response(404,"Not found")
        end
    end
end

function queue(req::HTTP.Request)
    path = HTTP.URI(req.target).path
    analysisid = split(path,"$(basedir)/queue/")[2]

    @show DIVAnd_tasks[analysisid], isready(DIVAnd_tasks[analysisid])
    if isready(DIVAnd_tasks[analysisid])
        DIVAnd_tasks_status[analysisid] = take!(DIVAnd_tasks[analysisid])
    end

    filename = analysisname(analysisid)
    retry = 4
    if isfile(filename)
        @show "return file"

        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            body = JSON.json(Dict(
                "status" => "done",
                # relative URL to the DIVAnd gui
                "url" => "$(version)/analysis/$(analysisid)"))
        )

    else
        return HTTP.Response(
            200,
            ["Cache-Control" => "max-age=$(retry)",
             "Content-Type" => "application/json"],
            body = JSON.json(Dict(
               "status" => "pending",
               "message" => DIVAnd_tasks_status[analysisid])))
    end
end

function upload(req::HTTP.Request)
    data = JSON.parse(
        HTTP.payload(req,String);
        dicttype=DataStructures.OrderedDict)

    @show data

    server = WebDAV(data["webdav"],data["username"],data["password"])

    # HTTP.open("GET", data["url"],[]) do stream
    #     #open(server,data["webdav_path"],"w") do out
    #     open("/tmp/toto123","w") do out
    #         while !eof(stream)
    #             data = readavailable(stream)
    #             @show typeof(data)
    #             write(out,data)
    #         end
    #     end
    # end

    open(Base.download(data["url"]),"r") do stream
        @show "upload",data["url"]
        upload(server,stream,data["webdav_path"])
        @show "done upload",data["url"]
    end

    return HTTP.Response(200,"move")
end

function route!(fun,router,method,url)
    HTTP.register!(router, method, url, HTTP.HandlerFunction(fun))
end

function listvarnames(data)
    obsname = resolvedata(data["observations"])
    Dataset(obsname) do ds
        varnames = filter(v -> (!(get(ds[v].attrib,"standard_name","") in ["longitude","latitude","depth","time"])
                                && (v != "obsid") ),
                          keys(ds))
        @debug "varnames $(varnames)"
        return JSON.json("varnames" => varnames)
    end
end

function http_listvarnames(req::HTTP.Request)
    data =
        if req.method == "POST"
            JSON.parse(
                HTTP.payload(req,String);
                dicttype=DataStructures.OrderedDict)
        else
            HTTP.queryparams(HTTP.URI(req.target))
        end

    @debug "data $(data)"

    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        body = listvarnames(data))
end


function preview(req::HTTP.Request)
    path = HTTP.URI(req.target).path
    analysisid,varname,zindexstr,tindexstr = split(split(path,"$(basedir)/preview/")[2],"/")

    zindex = parse(Int,zindexstr)
    tindex = parse(Int,tindexstr)
    fname = analysisname(analysisid)

    @show fname
    OceanPlot.hview(fname,String(varname),:,:,zindex,tindex)
    buf = IOBuffer()
    savefig(buf; format = "png")

    return HTTP.Response(
        200,
        ["Content-Type" => "image/png"],
        body = take!(buf))
end


HTTP.register!(router, "GET",  "$basedir/bathymetry",HTTP.HandlerFunction(bathymetry))

HTTP.register!(router, "POST", "$basedir/analysis",HTTP.HandlerFunction(analysis))
HTTP.register!(router, "GET",  "$basedir/analysis",HTTP.HandlerFunction(analysis))
HTTP.register!(router, "OPTIONS",  "$basedir/analysis",HTTP.HandlerFunction(options_analysis))

HTTP.register!(router, "GET",  "$basedir/queue",HTTP.HandlerFunction(queue))
HTTP.register!(router, "POST", "$basedir/upload",HTTP.HandlerFunction(upload))


HTTP.register!(router, "POST", "$basedir/listvarnames",
               HTTP.HandlerFunction(http_listvarnames))


HTTP.register!(router, "GET",  "$basedir/preview",HTTP.HandlerFunction(preview))

server = HTTP.Servers.Server(router)
#task = @async HTTP.serve(server, HTTP.ip"127.0.0.1", port; verbose=false)
task = @async HTTP.serve(server, HTTP.ip"0.0.0.0", port; verbose=false)

# e.g.
# "http://127.0.0.1:8001/v1"
URL = baseurl * basedir
