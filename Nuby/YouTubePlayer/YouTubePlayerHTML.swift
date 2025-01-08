import Foundation

struct YouTubePlayerHTML {
    static func generateHTML(videoID: String, playerVars: [String: Any]) -> String {
        // Merge default player vars with custom ones
        var defaultPlayerVars: [String: Any] = [
            "playsinline": 1,        // Enable inline playback
            "controls": 1,           // Show player controls
            "enablejsapi": 1,        // Enable JavaScript API
            "rel": 0,               // Don't show related videos
            "fs": 1,                // Enable fullscreen button
            "modestbranding": 1,    // Hide YouTube logo
            "origin": "https://www.youtube.com"
        ]
        
        // Merge with custom player vars
        playerVars.forEach { defaultPlayerVars[$0] = $1 }
        
        // Convert player vars to JSON string
        let playerVarsJSON = (try? JSONSerialization.data(withJSONObject: defaultPlayerVars))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    width: 100vw;
                    height: 100vh;
                    background-color: black;
                }
                #player {
                    position: absolute;
                    width: 100%;
                    height: 100%;
                    top: 0;
                    left: 0;
                    background-color: black;
                }
                .video-container {
                    position: relative;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                }
            </style>
        </head>
        <body>
            <div class="video-container">
                <div id="player"></div>
            </div>
            
            <script>
                // Load YouTube IFrame API
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                
                var player;
                var isPlayerReady = false;
                var pendingSeek = null;
                var messageQueue = [];
                var isProcessingQueue = false;
                
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        videoId: '\(videoID)',
                        playerVars: \(playerVarsJSON),
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onPlaybackQualityChange': onPlaybackQualityChange,
                            'onPlaybackRateChange': onPlaybackRateChange,
                            'onError': onPlayerError
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    isPlayerReady = true;
                    sendMessage({
                        'event': 'ready'
                    });
                    
                    // Handle any pending seek
                    if (pendingSeek !== null) {
                        seekVideo(pendingSeek);
                        pendingSeek = null;
                    }
                    
                    // Start time updates
                    startTimeUpdates();
                }
                
                function startTimeUpdates() {
                    function updateTime() {
                        if (player && player.getCurrentTime) {
                            var currentTime = player.getCurrentTime();
                            sendMessage({
                                'event': 'timeUpdate',
                                'time': currentTime
                            });
                        }
                        requestAnimationFrame(updateTime);
                    }
                    updateTime();
                }
                
                function onPlayerStateChange(event) {
                    sendMessage({
                        'event': 'stateChange',
                        'state': event.data
                    });
                    
                    // Restart time updates when playing
                    if (event.data === YT.PlayerState.PLAYING) {
                        startTimeUpdates();
                    }
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
                
                function onPlayerError(event) {
                    var errorMessage = 'Unknown error';
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
                
                // Optimized message sending with queue
                function sendMessage(message) {
                    messageQueue.push(message);
                    if (!isProcessingQueue) {
                        processMessageQueue();
                    }
                }
                
                function processMessageQueue() {
                    if (messageQueue.length === 0) {
                        isProcessingQueue = false;
                        return;
                    }
                    
                    isProcessingQueue = true;
                    const message = messageQueue.shift();
                    try {
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify(message));
                    } catch (error) {
                        console.error('Error sending message:', error);
                    }
                    
                    // Process next message in next tick
                    setTimeout(processMessageQueue, 0);
                }
                
                // Expose seekVideo function for backward compatibility
                window.seekVideo = function(seconds) {
                    if (!player || !isPlayerReady) {
                        pendingSeek = seconds;
                        return;
                    }
                    
                    try {
                        const targetTime = Math.round(seconds * 10) / 10;
                        player.seekTo(targetTime, true);
                        sendMessage({
                            'event': 'seeked',
                            'time': targetTime
                        });
                    } catch (error) {
                        sendMessage({
                            'event': 'error',
                            'error': 'Seek error: ' + error.message
                        });
                    }
                };
                
                // Handle orientation changes
                window.addEventListener('orientationchange', function() {
                    // Let YouTube handle the rotation
                    setTimeout(function() {
                        if (player && player.getPlayerState() === YT.PlayerState.PLAYING) {
                            // Force player to adapt to new orientation
                            player.playVideo();
                        }
                    }, 100);
                });
            </script>
        </body>
        </html>
        """
    }
}
