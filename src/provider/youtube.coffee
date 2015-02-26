Promise = require 'bluebird'
querystring = require 'querystring'

{ getJSON } = require '../request'
Media = require '../media'

API_KEY = null

# https://en.wikipedia.org/wiki/ISO_8601#Durations
DURATION_SCALE = [
    [/(\d+)D/, 24*3600],
    [/(\d+)H/, 3600],
    [/(\d+)M/, 60],
    [/(\d+)S/, 1]
]

parseDuration = (duration) ->
    time = 0
    for [regex, scale] in DURATION_SCALE
        if m = duration.match(regex)
            time += parseInt(m[1]) * scale

    return time

exports.lookup = lookup = (id) ->
    if not API_KEY
        return Promise.reject(new Error('API key not set for YouTube v3 API'))

    params = querystring.stringify(
        key: API_KEY
        part: 'contentDetails,status,snippet'
        id: id
    )

    url = "https://www.googleapis.com/youtube/v3/videos?#{params}"

    return getJSON(url).then((result) ->

        # Sadly, as of the v3 API, YouTube doesn't tell you *why* the request failed.
        if result.items.length == 0
            throw new Error('Video does not exist or is private')

        video = result.items[0]

        if not video.status.embeddable
            throw new Error('Video is not embeddable')

        data =
            id: id
            type: 'youtube'
            title: video.snippet.title
            duration: parseDuration(video.contentDetails.duration)
            meta:
                thumbnail: video.snippet.thumbnails.default.url

        if video.contentDetails.regionRestriction
            restriction = video.contentDetails.regionRestriction
            data.meta.blocked = restriction.blocked if restriction.blocked
            data.meta.allowed = restriction.allowed if restriction.allowed

        return new Media(data)
    )

exports.setApiKey = (key) ->
    API_KEY = key