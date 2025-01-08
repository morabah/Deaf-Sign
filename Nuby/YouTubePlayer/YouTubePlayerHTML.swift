import Foundation

struct YouTubePlayerHTML {
    static func generateHTML(videoID: String, playerVars: [String: Any] = [:]) -> String {
        // Convert player vars to JSON string
        let defaultPlayerVars: [String: Any] = [
            "playsinline": 1,
            "rel": 0,
            "controls": 1,
            "enablejsapi": 1,
            "origin": "file://",
            "modestbranding": 1,
            "fs": 1,
            "autoplay": 0,
            "showinfo": 1
        ]
        
        // Merge default and custom player vars
        let mergedPlayerVars = defaultPlayerVars.merging(playerVars) { _, new in new }
        let playerVarsJSON = (try? JSONSerialization.data(withJSONObject: mergedPlayerVars))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body { margin: 0; background-color: transparent; }
                .container { 
                    position: relative; 
                    padding-bottom: 56.25%; /* 16:9 aspect ratio */
                    height: 0; 
                    overflow: hidden; 
                    transition: all 0.3s ease;
                }
                #player { 
                    position: absolute; 
                    top: 0; 
                    left: 0; 
                    width: 100%; 
                    height: 100%; 
                    transition: all 0.3s ease;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div id="player"></div>
            </div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
                let player;
                let isPlayerReady = false;
                let currentTime = 0;
                let timeUpdateInterval = null;
                let pendingSeek = null;
                let pendingPlaybackRate = null;
                let pendingPlaybackQuality = null;
                
                function onYouTubeIframeAPIReady() {
                    console.log('YouTube API Ready');
                    const playerVars = \(playerVarsJSON);
                    player = new YT.Player('player', {
                        videoId: '\(videoID)',
                        playerVars: playerVars,
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError,
                            'onPlaybackQualityChange': onPlaybackQualityChange,
                            'onPlaybackRateChange': onPlaybackRateChange
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    console.log('Player Ready');
                    isPlayerReady = true;
                    startTimeUpdates();
                    
                    // Handle any pending operations
                    if (pendingSeek !== null) {
                        player.seekTo(pendingSeek, true);
                        pendingSeek = null;
                    }
                    if (pendingPlaybackRate !== null) {
                        player.setPlaybackRate(pendingPlaybackRate);
                        pendingPlaybackRate = null;
                    }
                    if (pendingPlaybackQuality !== null) {
                        player.setPlaybackQuality(pendingPlaybackQuality);
                        pendingPlaybackQuality = null;
                    }
                    
                    // Send ready event
                    sendMessage({
                        'event': 'ready',
                        'availablePlaybackRates': player.getAvailablePlaybackRates(),
                        'availableQualityLevels': player.getAvailableQualityLevels()
                    });
                }
                
                function onPlaybackQualityChange(event) {
                    sendMessage({
                        'event': 'playbackQualityChange',
                        'quality': event.data
                    });
                }
                
                function onPlaybackRateChange(event) {
                    sendMessage({
                        'event': 'playbackRateChange',
                        'rate': event.data
                    });
                }
                
                function startTimeUpdates() {
                    if (timeUpdateInterval) {
                        clearInterval(timeUpdateInterval);
                    }
                    timeUpdateInterval = setInterval(updateCurrentTime, 100);
                }
                
                function updateCurrentTime() {
                    if (player && player.getCurrentTime && isPlayerReady) {
                        try {
                            currentTime = player.getCurrentTime();
                            sendMessage({
                                'event': 'timeUpdate',
                                'time': currentTime,
                                'duration': player.getDuration(),
                                'loadedFraction': player.getVideoLoadedFraction()
                            });
                        } catch (error) {
                            console.error('Error updating time:', error);
                            sendMessage({
                                'event': 'error',
                                'error': 'Time update error: ' + error.message
                            });
                        }
                    }
                }
                
                function stopTimeUpdates() {
                    if (timeUpdateInterval) {
                        clearInterval(timeUpdateInterval);
                        timeUpdateInterval = null;
                    }
                }
                
                function onPlayerStateChange(event) {
                    console.log('Player State Changed:', event.data);
                    if (event.data === YT.PlayerState.PLAYING) {
                        startTimeUpdates();
                    } else if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
                        stopTimeUpdates();
                    }
                    sendMessage({
                        'event': 'stateChange',
                        'state': event.data
                    });
                }
                
                function onPlayerError(event) {
                    console.error('Player Error:', event.data);
                    stopTimeUpdates();
                    isPlayerReady = false;
                    let errorMessage = 'Unknown error';
                    switch(event.data) {
                        case 2: errorMessage = 'Invalid video ID'; break;
                        case 5: errorMessage = 'HTML5 player error'; break;
                        case 100: errorMessage = 'Video not found'; break;
                        case 101:
                        case 150: errorMessage = 'Video not playable in embedded player'; break;
                    }
                    sendMessage({
                        'event': 'error',
                        'error': errorMessage
                    });
                }
                
                function sendMessage(message) {
                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify(message));
                }
                
                // Expose seekVideo function for backward compatibility
                window.seekVideo = function(seconds) {
                    console.log('Seeking to:', seconds);
                    if (!player || !isPlayerReady) {
                        console.log('Player not ready, storing seek time');
                        pendingSeek = seconds;
                        return;
                    }

                    try {
                        const targetTime = Math.round(seconds * 10) / 10;
                        player.seekTo(targetTime, true);
                        
                        if (player.getPlayerState() !== YT.PlayerState.PLAYING) {
                            player.playVideo();
                        }
                        
                        sendMessage({
                            'event': 'seeked',
                            'time': targetTime
                        });
                    } catch (error) {
                        console.error('Seek error:', error);
                        sendMessage({
                            'event': 'error',
                            'error': 'Seek error: ' + error.message
                        });
                    }
                };
                
                // Handle orientation changes
                function handleOrientationChange() {
                    const container = document.querySelector('.container');
                    const playerElement = document.getElementById('player');
                    if (window.orientation === 90 || window.orientation === -90) {
                        container.style.paddingBottom = '0';
                        container.style.height = '100vh';
                        playerElement.style.width = '100vw';
                        playerElement.style.height = '100vh';
                    } else {
                        container.style.paddingBottom = '56.25%';
                        container.style.height = '0';
                        playerElement.style.width = '100%';
                        playerElement.style.height = '100%';
                    }
                }
                
                window.addEventListener('orientationchange', handleOrientationChange);
                window.addEventListener('resize', handleOrientationChange);
                
                // Global error handling
                window.onerror = function(message, source, lineno, colno, error) {
                    console.error('JavaScript error:', message);
                    sendMessage({
                        'event': 'error',
                        'error': 'JavaScript error: ' + message
                    });
                    return false;
                };
            </script>
        </body>
        </html>
        """
    }
}
