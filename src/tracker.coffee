serverHost = "http://meusu-tracker.herokuapp.com"
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
      port: serverPort

    @socket.on "position", @onPosition
    @socket.on "clear", @onClear

    $("#position").text "Waiting for position.."

  onPosition: (position, name) =>
    return unless name == @name

    $("#position").html """
      Latitude: #{position.latitude}<br/>
      Longitude: #{position.longitude}
                        """

    @map.setPosition position.latitude, position.longitude

  onClear: (name) =>
    return unless name == @name

    @map.clearPosition()

class Tracking
  constructor: (@ui) ->
    @reportUrl = "#{serverHost}/report"
    @clearUrl  = "#{serverHost}/clear"

    @pollingInterval = 1 * 60 * 1000 # 1 minute

    document.addEventListener "pause",  @onPause,  false
    document.addEventListener "resume", @onResume, false

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
      params:           { name: @name }
      desiredAccuracy:  0
      stationaryRadius: 20
      distanceFilter:   30

  getCurrentPosition: =>
    window.navigator.geolocation.getCurrentPosition @onPosition, @onFailure

  startForegroundTracker: ->
    @getCurrentPosition()
    @foregroundTracker = setInterval @getCurrentPosition, @pollingInterval

  stopForegroundTracker: ->
    clearInterval @foregroundTracker if @foregroundTracker?

  setupUi: ->
    $("#start").removeAttr "disabled"

    $("#start").click =>
      unless @name?
        @name = $("#name").val()
        @ui.name = @name
        @configure()

      if $("#start").hasClass "btn-success"
        @startForegroundTracker()
        $("#name").prop "disabled", true
        $("#start").removeClass("btn-success").addClass("btn-danger").text "Stop Tracking"
      else
        $.post @clearUrl, {name: @name}, null, "json"
        @stopForegroundTracker()
        $("#position").text "Waiting for position.."
        $("#start").removeClass("btn-danger").addClass("btn-success").text "Start Tracking"

  start: ->
    @setupUi()

  onPosition: (position) =>
    return if $("#start").hasClass "btn-success"

    position = position.coords || position
    $.post @reportUrl, {name: @name, location: position}, null, "json"
    @bgGeo.finish()

  onFailure: (error) =>
    console.log "error", error

  onPause: =>
    return unless $("#start").hasClass "btn-danger"
    # Start background service
    @bgGeo.start()

  onResume: =>
    @bgGeo.stop()

class window.Tracker
  constructor: ->
    document.addEventListener "deviceready", @onReady, false

  onReady: =>
    @ui       = new Ui
    @tracking = new Tracking @ui

    @ui.start()
    @tracking.start()
