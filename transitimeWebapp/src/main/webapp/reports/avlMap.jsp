<%@ page import="org.transitime.utils.web.WebUtils" %>
<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1"%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
  <!-- So that get proper sized map on iOS mobile device -->
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  
  <link rel="stylesheet" href="<%= request.getContextPath() %>/map/css/mapUi.css" />
 
  <!-- Load javascript and css files -->
  <%@include file="/template/includes.jsp" %>
  
  <link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.7.3/leaflet.css" />
  <script src="http://cdn.leafletjs.com/leaflet-0.7.3/leaflet.js"></script>
        
  <script src="<%= request.getContextPath() %>/map/javascript/leafletRotatedMarker.js"></script>
  <script src="<%= request.getContextPath() %>/map/javascript/mapUiOptions.js"></script>
  
   <!-- Load in Select2 files so can create fancy route selector -->
  <link href="../select2/select2.css" rel="stylesheet"/>
  <script src="../select2/select2.min.js"></script>
    
  <!--  Override the body style from the includes.jsp/general.css files -->
  <style>
    body {
	  margin: 0px;
    }
    
    /* For the AVL points */
	div.avlTriangle {
	  width: 0px;
  	  height: 0px;
  	  border-bottom: 10px solid #ff7800;
  	  border-left: 5px solid transparent;
  	  border-right: 5px solid transparent
  	 }
    
    .popupTable {
      border-spacing: 0px;
    }
    	
    .popupTableLabel {
      font-weight: bold;
      text-align: right;
    }
    
    /* For the params menu */
    #params {
      background: lightgrey;
      position:absolute;
      top:10px;
      right:10px;
      border-radius: 25px;
      padding: 2%;
    }
    
    .param {
      margin-top: 10px;
      text-align: right;
    }
    
    /* overide mapUi.css */
    #params div {
      visibility: visible; 
      left: 0%;
    }
    
    /* Playback menu */
    #playback {
    	background: white;
    	position: absolute;
    	left: 50%;
    	bottom: 10px;
    }
    
  </style>

  <script>
  /* For drawing the route and stops */
  var routeOptions = {
			color: '#00ee00',
			weight: 4,
			opacity: 0.4,
			lineJoin: 'round',
			clickable: false
		};
				
  var stopOptions = {
		    color: '#006600',
		    opacity: 0.4,
		    radius: 4,
		    weight: 2,
		    fillColor: '#006600',
		    fillOpacity: 0.3,
		};

  var routePolylineOptions = {clickable: false, color: "#00f", opacity: 0.5, weight: 4};

  var avlPopupOptions = {closeButton: false};

  var stopPopupOptions = {closeButton: false};

  </script>
  
  <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
  
  <title>AVL Data Map</title>
  
  <script>
  
  // vehicles is a list of {id: vehicle_id, data: [avl1, avl2, ...]}
  var vehicles = [];
  
  /* Called when user clicks on map. Displays AVL data */
  function showAvlPopup(avlMarker) {
  	var avl = avlMarker.avl;
  	var speed = Math.round(parseFloat(avl.speed) * 10)/10;
	var content = "<table class='popupTable'>" 
		+ "<tr><td class='popupTableLabel'>Vehicle:</td><td>" + avl.vehicleid + "</td></tr>" 
		+ "<tr><td class='popupTableLabel'>GPS Time:</td><td>" + avl.time + "</td></tr>" 
  		+ "<tr><td class='popupTableLabel'>Time Proc:</td><td>" + avl.timeprocessed + "</td></tr>"
 		+ "<tr><td class='popupTableLabel'>Lat/Lon:</td><td>" + avl.lat + ", " + avl.lon + "</td></tr>"
  		+ "<tr><td class='popupTableLabel'>Speed:</td><td>" + speed + " kph</td></tr>"
  		+ "<tr><td class='popupTableLabel'>Heading:</td><td>" + avl.heading + "</td></tr>"
  		+ "</table>";
	  		
  	  L.popup(avlPopupOptions)
		.setLatLng(avlMarker.getLatLng())
		.setContent(content)
		.openOn(map);

  }

	
  function drawAvlMarker(avl) {
	var latLng = L.latLng(avl.lat, avl.lon);
	  
	// Create the marker. Use a divIcon so that can have tooltips
  	var tooltip = avl.time.substring(avl.time.indexOf(' ') + 1);  
  	var avlMarker = L.marker(latLng, {
          icon: L.divIcon({
        		 className: 'avlMarker',
        		 html: "<div class='avlTriangle icon_" + avl.vehicleId + "' style='transform: rotate("+ avl.heading + "deg);' />",
        		 iconSize: [7,7]
        	  }),
          title: tooltip
      }).addTo(group); 
	
  	// Store the AVL data with the marker so can popup detailed info
	avlMarker.avl = avl;
	
  	// When user clicks on AVL marker popup information box
	avlMarker.on('click', function(e) {
		showAvlPopup(this);
	});
  	
  	return avlMarker;
  }
  
  /* Called when receiving the AVL data via AJAX call */
  function processAvlCallback(jsonData) {
	  	  
	/* Save avl data */ 
	
    // List of all the latLngs
    var latLngs = [];

    // So can draw separate polyline per vehicle
    var previousVehicleId = "";
    var latLngsForVehicle = [];
    
    // For each AVL report...
    var vehicle;
    for (var i=0; i<jsonData.data.length; ++i) {
    	var avl = jsonData.data[i];
    	
    	// If getting data for new vehicle then need to draw out polyline 
    	// for the old vehicle
		if (avl.vehicleId != previousVehicleId) {		    
	    	// Create a line connecting the AVL locations as long as there are 
	    	// at least 2 AVL reports for the vehicle
	    	if (latLngsForVehicle.length >= 2)
	    		L.polyline(latLngsForVehicle, routePolylineOptions).addTo(map); //.bringToBack();
	    	latLngsForVehicle = [];
	    	vehicle = {id: avl.vehicleId, data: []}
	    	vehicles.push(vehicle);
		} 
		
    	// parse date string -> number
    	avl.timenum = Date.parse(avl.time.replace(/-/g, '/').slice(0,-2))
    	
		vehicle.data.push(avl)
		previousVehicleId = avl.vehicleId;
		
		var latLng = drawAvlMarker(avl).getLatLng();

		latLngsForVehicle.push(latLng);
		latLngs.push(latLng);
    }
    
    // Draw polyline for the last vehicle in the AVL data
    if (latLngsForVehicle.length >= 2)
    	L.polyline(latLngsForVehicle, routePolylineOptions).addTo(group); //.bringToBack();
    
    // If actually read AVL data...
    if (latLngs.length > 0) {
    	// To make all AVL reports fit in bounds of map.
    	map.fitBounds(latLngs);
  	} else {
		alert("No AVL data for the criteria specified.")
  	}
  }

  /* Called when user clicks on map. Displays AVL data */
  function showStopPopup(stopMarker) {
	  var stop = stopMarker.stop;
	  
	  var content = "<table class='popupTable'>" 
			+ "<tr><td class='popupTableLabel'>Stop ID:</td><td>" + stop.id + "</td></tr>" 
			+ "<tr><td class='popupTableLabel'>Name:</td><td>" + stop.name + "</td></tr>" 
	  		+ "</table>";
	  
	  L.popup(stopPopupOptions)
		.setLatLng(stopMarker.getLatLng())
		.setContent(content)
		.openOn(map);
  }
  
  /**
   * Reads in route data obtained via AJAX and draws route and stops on map.
   */
  function routeConfigCallback(route, status) {
	// Draw the paths for the route
	for (var i=0; i<route.shape.length; ++i) {
		var shape = route.shape[i];
		var latLngs = [];		
		for (var j=0; j<shape.loc.length; ++j) {
			var loc = shape.loc[j];			
			latLngs.push(L.latLng(loc.lat, loc.lon));
		}
		L.polyline(latLngs, routeOptions).addTo(group);
	}
	  
  	// Draw stops for the route. 
  	for (var i=0; i<route.direction.length; ++i) {
  		var direction = route.direction[i];
  		for (var j=0; j<direction.stop.length; ++j) {
  			var stop = direction.stop[j];
  			
  			// Create the stop Marker
  			var stopMarker = L.circleMarker([stop.lat,stop.lon], stopOptions).addTo(group);
  			
  			// Store stop data obtained via AJAX with stopMarker so it can be used in popup
  			stopMarker.stop = stop;
  			
  			// When user clicks on stop popup information box
  			stopMarker.on('click', function(e) {
  				showStopPopup(this);
  			}).addTo(group);
  		}
   	 }
  }

  </script>
</head>

<body>
  <div id="map"></div>
  <div id="params">
  	<jsp:include page="params/vehicle.jsp" />
  	<jsp:include page="params/fromToDateTime.jsp" />
    <jsp:include page="params/routeSingle.jsp" /> 
  </div>
  <div id="playback">
  	<a href='#' id="playbackPrev">prev</a><br>
  	<a href='#' id="playbackPlay">play</a><br>
  	<span id="playbackTime">00:00:00</span>
  </div>
</body>

<script>

// Add a new layer for only route/bus markers, so that it can be refreshed
// when selections change without having to redraw tiles.
var map = L.map('map');
L.control.scale({metric: false}).addTo(map);
L.tileLayer('http://api.tiles.mapbox.com/v4/transitime.j1g5bb0j/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoidHJhbnNpdGltZSIsImEiOiJiYnNWMnBvIn0.5qdbXMUT1-d90cv1PAIWOQ', {
    attribution: '&copy; <a href="http://openstreetmap.org">OpenStreetMap</a> &amp; <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery � <a href="http://mapbox.com">Mapbox</a>',
    maxZoom: 19
}).addTo(map);

var group = L.layerGroup().addTo(map);

// Set the CLIP_PADDING to a higher value so that when user pans on map
// the route path doesn't need to be redrawn. Note: leaflet documentation
// says that this could decrease drawing performance. But hey, it looks
// better.
L.Path.CLIP_PADDING = 0.8;

var request = {<%= WebUtils.getAjaxDataString(request) %>};

// Set all the controls to match the values in the request.
$("#vehicle").val(request.v).trigger("change");
$("#beginDate").val(request.beginDate).trigger("change");
$("#endDate").val(request.endDate).trigger("change");
$("#beginTime").val(request.beginTime).trigger("change");
$("#endTime").val(request.endTime).trigger("change");
$("#route").val(request.r).trigger("change");


$(".param input").on("change", function() {
	
	/* Set request object to match new values */
	request.v = $("#vehicle").val();
	request.beginDate = $("#beginDate").val();
	request.endDate = $("#endDate").val();
	request.beginTime = $("#beginTime").val();
	request.endTime = $("#endTime").val();
	request.r = $("#route").val();

	
	/* Clear existing layer and draw new objects on map. */
	group.clearLayers();
	drawAvlData();
});

// Get the AVL data via AJAX and call processAvlCallback to draw it
function drawAvlData() {
	$.ajax({
	  	// The page being requested
	    url: "/web/reports/avlJsonData.jsp",
		// Pass in query string parameters to page being requested
		data: request,
		// Needed so that parameters passed properly to page being requested
		traditional: true,
	    dataType:"json",
	    async: true,
	    // When successful process JSON data
	    success: processAvlCallback,
	    // When there is an AJAX problem alert the user
	    error: function(request, status, error) {
	      alert(error + '. ' + request.responseText);
	    },
	});
	
	// If route specified then display it
	var route = request.r;
	if (route != "") {
		var url = apiUrlPrefix + "/command/route?r=" + route;
		$.getJSON(url, routeConfigCallback);
	}

}

drawAvlData();

/* Playback functionality */

var currTime;

$("#playbackPrev").on("click", function() {
	group.clearLayers();
	
	var times = vehicles.map(function(v) { return (v.data[0].timenum) });
	currTime = Math.min.apply(null, times);
	
	for (i = 0; i < vehicles.length; i++) {
		var v = vehicles[i];
		v.marker = drawAvlMarker(v.data[0]);
		v.avlIndex = 0;
	}

	console.log(vehicles[0])
	$("#playbackTime").text(parseTime(currTime));
});

$("#playbackPlay").on("click", function() {
	function tick() {
		var stop = true;
		currTime += 1000;
		
		// for each vehicle, update the position if the next AVL reflects a time 
		// less than the current time
		for (i = 0; i < vehicles.length; i++) {
			var v = vehicles[i];
			
			if (v.avlIndex + 1 == v.data.length) {
				continue;
			}
			stop = false;
		
			if (v.data[v.avlIndex+1].timenum <= currTime) {
				v.avlIndex += 1;
				var avl = v.data[v.avlIndex];
				
				// change position
				var latLng = L.latLng(avl.lat, avl.lon);
				v.marker.setLatLng(latLng);
				v.marker.update();
				
				// change heading
				$(".icon_"+v.id).attr("style", "transform: rotate("+ avl.heading + "deg");
				
			}
		}
		
		$("#playbackTime").text(parseTime(currTime));
		
		// setTimeout instead of requestAnimationFrame because we are only doing
		// this once per second
		if (!stop)
			setTimeout(tick, 1)
	}
	tick();
});

			

function parseTime(x) {
	return new Date(x).toTimeString().slice(0, 8);
}


// Edit route input width. TODO: should I just copy from route.jsp?
$('#route').attr("style", "width: 200px");



</script>
</html>