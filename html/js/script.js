var baseurl = window.location.href;
var divand = new DIVAnd(baseurl);

var FIELDS = {
    "observations": {
        "name": "URL of the observations",
        "description": ""
    },
    "varname": {
        "name": "Name of the variable",
        "description": ""
    },
    "bbox": {
        "name": "Bounding box (east, south, west, north)",
        "description": ""
    },
    "depth": {
        "name": "Comma separated list of depth levels",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction (meters)",
        "description": ""
    },
    "epsilon2": {
        "name": "Error voariance of observation (relative to the error variance of the background field)",
        "description": ""
    },
    "resolution": {
        "name": "Resolution in zonal and meridional direction (arc degree)",
        "description": ""
    },
    "years": {
        "name": "Start and end year",
        "description": ""
    },
    "monthlist": {
        "name": "Month of every season",
        "description": ""
    },
    "bathymetry": {
        "name": "Bathymetry",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
    "len": {
        "name": "Correlation length in zonal and meridional direction",
        "description": ""
    },
}
var SAMPLE_DATA = {
   "observations": "sampledata:WOD-Salinity",
   //"observations": "https://b2drop.eudat.eu/s/UsF3RyU3xB1UM2o/download",
   "varname": "Salinity",
   "bbox": [
      3.0,
      42.0,
      12.0,
      44.5
   ],
   "depth": [
       0,
       20,
       50
   ],
   "len": [
      100000.0,
      100000.0
   ],
   "epsilon2": 1.0,
   //"resolution": [      0.05,      0.05   ],
   "resolution": [      0.5,      0.5   ],
   "years": [
      1900,
      2018
   ],
   "monthlist": [
      [         1,         2,         3      ],
      [         4,         5,         6      ],
      [         7,         8,         9      ],
      [         10,         11,         12      ]
   ],
   "bathymetry": "sampledata:gebco_30sec_16",
   "metadata_project": "SeaDataCloud",
   "metadata_institution_urn": "SDN:EDMO::1579",
   "metadata_production": "Diva group. E-mails: a.barth@ulg.ac.be, swatelet@ulg.ac.be",
   "metadata_Author_e-mail": [
      "Your Name1 <name1@example.com>",
      "Other Name <name2@example.com>"
   ],
   "metadata_source": "observational data from SeaDataNet/EMODNet Chemistry Data Network",
   "metadata_comment": "...",
   "metadata_parameter_keyword_urn": "SDN:P35::EPC00001",
   "metadata_search_keywords_urn": [
      "SDN:P02::PSAL"
   ],
   "metadata_area_keywords_urn": [
      "SDN:C19::3_3"
   ],
   "metadata_product_version": "1.0",
   "metadata_netcdf_standard_name": "sea_water_salinity",
   "metadata_netcdf_long_name": "sea water salinity",
   "metadata_netcdf_units": "1e-3",
   "metadata_abstract": "...",
   "metadata_acknowledgment": "...",
   "metadata_doi": "..."
};



function checkAnalysis(url,request,callback) {
    var xhr = new XMLHttpRequest();

    xhr.open("GET", url, true);
    xhr.onreadystatechange = function () {

        if (xhr.readyState === 4 && xhr.status === 200) {
            console.log("length",xhr.responseText.length,xhr.getResponseHeader('Cache-Control'));
            var jsonResponse = JSON.parse(xhr.responseText);

            // callback
            callback(request,jsonResponse);

            if (jsonResponse.status === "pending") {
                setTimeout(function(){
                    console.log("recheck");
                    checkAnalysis(url,request,callback);
                }, 3000);
            }
            else {
                // done!
        	    console.log("ok, done", jsonResponse);
            }
        }

    };
    xhr.send(null);
}


/**
 * Represents a DIVAnd REST server
 * @constructor
 * @param {string} baseurl - The base URL of the REST API (without, e.g. v1/analysis/...)
 */
function DIVAnd(baseurl) {
    this.baseurl = baseurl || "";
    // remove trailing slash if present
    this.baseurl = this.baseurl.replace(/\/$/, "");
}

/**
 * Schedule a DIVAnd analysis
 * @function DIVAnd~analysis
 * @param {string} data - Parameters for the analysis
 * @param {DIVAnd~callback} callback - The callback that handles the response.
 */
DIVAnd.prototype.analysis = function(data,callback) {
    // Sending and receiving data in JSON format using POST method
    //
    var xhr = new XMLHttpRequest();
    var url = this.baseurl + "/v1/analysis";
    var that = this;

    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 2 && xhr.status === 202) {
            console.log("xhr.getResponseHeader('Location')",xhr.getResponseHeader('Location'));
            callback("processing",{});

            var newurl = that.baseurl + xhr.getResponseHeader('Location');
            checkAnalysis(newurl,{data: data},callback);
        }
    };
    xhr.send(JSON.stringify(data));
    callback("submitted",{});

}

/**
 * This callback is used for notifying the status of the analysis
 * @callback DIVAnd~callback
 * @param {string} step - "submitted","processing","done"
 * @param {object} data - additional data about the status
 */


DIVAnd.prototype.listvarnames = function(observations,callback) {
    var xhr = new XMLHttpRequest();
    var url = this.baseurl + "/v1/listvarnames";
    var that = this;

    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4 && xhr.status === 200) {
            var output = JSON.parse(xhr.responseText);
            console.log("resp ",output)
            callback(output);
        }
    };
    xhr.send(JSON.stringify({"observations": observations}));
}

function callback(request,data) {
    console.log("step",data);
    if (data.status) {
       document.getElementById("status").innerHTML = data.status;
    }

    if (data.message) {
        // build time index selector
        var tindex = document.getElementById("tindex");
        var current_tindex = tindex.value;
        while (tindex.firstChild) {
            tindex.removeChild(tindex.firstChild);
        }
        for (var i = 0; i < data.message.length; i++) {
            if (data.message[i].timeindex !== undefined) {
                var opt = document.createElement("option");
                opt.appendChild(document.createTextNode("" + data.message[i].timeindex));
                opt.value = "" + data.message[i].timeindex;
                tindex.appendChild(opt);
            }
        }
        // restore time index
        tindex.value = current_tindex;

        var lastmessage = data.message[data.message.length-1];

        if (lastmessage) {
            if (lastmessage.timeindex !== undefined) {
                var timeindex = lastmessage.timeindex;
                if (document.getElementById("update_preview").checked) {
                   tindex.value = timeindex;
                   update_preview(data.analysisid,request.data.varname);
                }
            }
        }
    }

    if (data.status === "done") {
        var result = document.getElementById("result");
        result.href = data.url;
        result.style.display = "block";
    }
}

function update_preview(analysisid,varname) {
    var timeindex = document.getElementById("tindex").value;
    var depthindex = document.getElementById("zindex").value;
    // http://localhost:8002/v1/preview/upMLcrKGWmulqwm0mKbmzwj7/Salinity/1/1
    var previewurl = divand.baseurl + "/v1" + "/preview/" + analysisid + "/" + varname + "/" + depthindex + "/" + timeindex;
    document.getElementById("preview").src = previewurl;
}

function update_varnames(varnames) {
    var parent = document.querySelector("input[name=varname]").parentNode;
    parent.removeChild(parent.firstElementChild);

    var select = document.createElement("select");
    select.setAttribute("name", "varname");

    //varnames = ["Salinity"]

    for (var i = 0; i < varnames.length; i++) {
        var opt = document.createElement("option");
        opt.appendChild(document.createTextNode(varnames[i]));
        opt.value = varnames[i];
        select.append(opt)
    }

    parent.appendChild(select);

}


function load_varnames() {
    var observations = document.querySelector("input[name=observations]").value;

    divand.listvarnames(observations,function(resp) {
        console.log(resp.varnames);
        update_varnames(resp.varnames);
    })
}

function run() {
    var data = SAMPLE_DATA;

    var baseurl = window.location.href;
    var divand = new DIVAnd(baseurl);

    table = document.getElementById("DIVAnd_table");
    var data = extractform(table,SAMPLE_DATA);

    document.getElementById("status").innerHTML = "";
    document.getElementById("result").style.display = "none";
    document.getElementById("preview").removeAttribute("src");

    divand.analysis(data,callback);

    zindex = document.getElementById("zindex");
    for (var i = 0; i < data.depth.length; i++) {
        var opt = document.createElement("option");
        opt.appendChild(document.createTextNode(data.depth[i]))
        opt.value = i+1;
        zindex.appendChild(opt);
    }
}



function appendform(table,data) {
    var tr, td, label, input, name;

    for (var key in data) {
        if (data.hasOwnProperty(key)) {
            console.log(key + " -> " + data[key]);

            tr = document.createElement("tr");
            td = document.createElement("td");
            label = document.createElement("label");

            name = key;
            if (FIELDS[key]) {
                name = FIELDS[key].name;
            }

            label.appendChild(document.createTextNode(name));
            td.appendChild(label);
            tr.appendChild(td);

            td = document.createElement("td");


            if (key === "monthlist")  {
                for (var i = 0; i < data[key].length; i++) {
                    input = document.createElement("input");
                    input.setAttribute("name", key);
                    input.setAttribute("type", "text");
                    input.setAttribute("data-type", "list");
                    input.setAttribute("value", data[key][i]);
                    td.appendChild(input);
                }
            }
            else  {
                input = document.createElement("input");
                input.setAttribute("type", "text");
                input.setAttribute("name", key);

                if (data[key].constructor === Array) {
                    value = data[key].join();
                }
                else {
                    value = data[key];
                }

                input.setAttribute("value", value);

                td.appendChild(input);
            }
            tr.appendChild(td);

            table.appendChild(tr);

        }
    }

}

function parse(sampleval,value) {
    if (typeof sampleval == "string") {
        return value;
    }
    else if (typeof sampleval == "number") {
        return parseFloat(value);
    }
    else if (sampleval.constructor === Array) {
        return value.split(",").map(function(elem) {
            console.log("elem",elem);
            return parse(sampleval[0],elem);
        });
    }

}

function extractform(table,data) {
    var d = {};

    for (var key in data) {
        if (data.hasOwnProperty(key)) {
            sampleval = data[key]

            if (key === "monthlist")  {
                inputs = table.querySelectorAll("[name=" + key + "]");
                val = Array.prototype.map.call(inputs,function(e) { return e.value });

                if (val[val.length-1] === "") {
                    val.splice(-1,1)
                }

                d[key] = val.map(function(e) { return parse(sampleval[0],e); });
            }
            else {
                value = table.querySelector("[name=" + key + "]").value;
                d[key] = parse(sampleval,value);
            }
        }
    }
    return d;
}


function test() {
    var baseurl = window.location.href;
    var divand = new DIVAnd(baseurl);

    var varnames;
    divand.listvarnames("sampledata:WOD-Salinity",function(v) { console.log(v);  })



}


var table, data, data2;

(function() {
   // your page initialization code here
    // the DOM will be available here


    var table = document.getElementById("DIVAnd_table");
    data = SAMPLE_DATA;
    appendform(table,data);

    document.getElementById("run").onclick = run;

    data2 = extractform(table,data);
    console.log(data2);

    table = document.getElementById("DIVAnd_table");
    table.onkeyup = function(event)  {
        //console.log("this",this,event.target);
        var target = event.target;
        var name = target.name;
        var next = target.nextSibling || {};

        if (target.value !== "" && target.getAttribute("data-type") === "list") {
            //console.log("nn",next);

            if (next.name !== target.name) {
                elem = target.cloneNode();
                elem.value = "";
                target.parentNode.insertBefore(elem,target.nextSibling);
            }
        }

        var l = document.querySelectorAll("input[name=" + name + "]");
        for (i =  l.length-1; i > 1; i--) {
            if (l[i].value === "" && l[i-1].value === "") {
                l[i].remove();
            }
        }
    };


    load_varnames();
    document.querySelector("input[name=observations]").onchange = load_varnames;


})();
