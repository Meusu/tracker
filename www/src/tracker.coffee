serverHost = "http://secondline-server.herokuapp.com"
serverPort = 80
#serverHost = "http://localhost"
#serverPort = 5000

class Map
  constructor: ->
    center = new google.maps.LatLng 29.947877, -90.114755
    @marker = null

    @map = new google.maps.Map document.getElementById("map-canvas"),
      disableDefaultUI: true
      draggable:        false
      zoom:             15
      center:           center
      mapTypeId:        google.maps.MapTypeId.ROADMAP

    @route = new google.maps.KmlLayer
      url: "http://mapsengine.google.com/map/u/0/kml?mid=zaIRRFV8XaRQ.k2GoQJ3ppZFs"
    @route.setMap @map

  setPosition: (lat, lng) ->
    if @marker?
      @marker.setMap null
      @marker = null

    position = new google.maps.LatLng lat, lng

    @marker = new google.maps.Marker
      position: position
      map:      @map
      title: "position"

    @map.setCenter position
    @map.setZoom 15

  clearPosition: ->
    if @marker?
      @marker.setMap null
      @marker = null

class Ui
  start: ->
    @map = new Map
    @socket = io.connect serverHost,
      transports: ["xhr-polling"]
      port:       serverPort

    @socket.on "position", @onPosition
    @socket.on "clear", @onClear

    $("#position").text "Waiting for position.."

  onPosition: (position) =>
    $("#position").html """
      Latitude: #{position.latitude}<br/>
      Longitude: #{position.longitude}
                        """

    @map.setPosition position.latitude, position.longitude

  onClear: =>
    @map.clearPosition()

class BackgroundTracking
  constructor: ->
    @reportUrl = "#{serverHost}/report"
    @clearUrl  = "#{serverHost}/clear"

  configure: ->
    @bgGeo = window.plugins?.backgroundGeoLocation ||
      configure: ->
        console.log "geo configure"
      start: ->
        console.log "geo start"
      stop: ->
        console.log "geo stop"
      finish: ->
        console.log "geo finish"

    @bgGeo.configure @onPosition, @onFailure,
      url:              @reportUrl
      desiredAccuracy:  0
      stationaryRadius: 20
      distanceFilter:   30

  setupUi: ->
    $("#start").removeAttr "disabled"

    $("#start").click =>
      if $("#start").hasClass "btn-success"
        # Fetch position right away..
        window.navigator.geolocation.getCurrentPosition @onPosition, @onFailure

        # Start background service
        @bgGeo.start()

        $("#start").removeClass("btn-success").addClass("btn-danger").text "Stop Tracking"
      else
        @bgGeo.stop()
        $("#position").text "Waiting for position.."
        $("#start").removeClass("btn-danger").addClass("btn-success").text "Start Tracking"
        $.post @clearUrl

  start: ->
    # Will prompt for location access
    window.navigator.geolocation.getCurrentPosition ->
    @configure()
    @setupUi()

  onPosition: (position) =>
    return if $("#start").hasClass "btn-success"

    position = position.coords || position
    $.post @reportUrl, {location: position}, null, "json"
    @bgGeo.finish()

  onFailure: (error) =>
    console.log "error", error

class window.Tracker
  constructor: ->
    document.addEventListener "deviceready", @onReady, false

  onReady: =>
    @ui       = new Ui
    @tracking = new BackgroundTracking

    @ui.start()
    @tracking.start()
