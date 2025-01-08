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
            "showinfo": 1,
            // Add performance optimization parameters
            "iv_load_policy": 3, // Disable video annotations
            "cc_load_policy": 0, // Disable closed captions by default
            "hl": Locale.current.languageCode ?? "en", // Set player language
            "widget_referrer": "file://", // Set referrer for analytics
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
                body { 
                    margin: 0; 
                    background-color: black; 
                    overflow: hidden; 
                }
                .container { 
                    position: relative; 
                    padding-bottom: 56.25%; 
                    height: 0; 
                    overflow: hidden; 
                    background-color: black;
                    transform: translate3d(0,0,0); /* Enable hardware acceleration */
                    will-change: transform; /* Optimize for animations */
                }
                #player { 
                    position: absolute; 
                    top: 0; 
                    left: 0; 
                    width: 100%; 
                    height: 100%; 
                    transform: translate3d(0,0,0);
                    will-change: transform;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div id="player"></div>
            </div>
            <script>
                // Performance optimization: Use passive event listeners
                const supportsPassive = (() => {
                    let supported = false;
                    try {
                        const opts = Object.defineProperty({}, 'passive', {
                            get: function() { supported = true; }
                        });
                        window.addEventListener('test', null, opts);
                    } catch (e) {}
                    return supported;
                })();
                
                const eventListenerOpts = supportsPassive ? { passive: true } : false;
                
                // Preload YouTube IFrame API
                const tag = document.createElement('script');
                tag.src = 'https://www.youtube.com/iframe_api';
                const firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                
                let player;
                let isPlayerReady = false;
                let currentTime = 0;
                let timeUpdateInterval = null;
                let pendingSeek = null;
                let pendingPlaybackRate = null;
                let pendingPlaybackQuality = null;
                let lastTimeUpdate = 0;
                const TIME_UPDATE_INTERVAL = 100; // ms
                
                function onYouTubeIframeAPIReady() {
                    console.log('YouTube API Ready');
                    const playerVars = \(playerVarsJSON);
                    
                    // Create player with optimized settings
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
                
                function startTimeUpdates() {
                    stopTimeUpdates();
                    timeUpdateInterval = setInterval(updateCurrentTime, TIME_UPDATE_INTERVAL);
                }
                
                function updateCurrentTime() {
                    if (!player || !isPlayerReady) return;
                    
                    const now = performance.now();
                    if (now - lastTimeUpdate < TIME_UPDATE_INTERVAL) return;
                    
                    try {
                        currentTime = player.getCurrentTime();
                        const duration = player.getDuration();
                        const loadedFraction = player.getVideoLoadedFraction();
                        
                        sendMessage({
                            'event': 'timeUpdate',
                            'time': currentTime,
                            'duration': duration,
                            'loadedFraction': loadedFraction
                        });
                        
                        lastTimeUpdate = now;
                    } catch (error) {
                        console.error('Error updating time:', error);
                        sendMessage({
                            'event': 'error',
                            'error': 'Time update error: ' + error.message
                        });
                    }
                }
                
                function stopTimeUpdates() {
                    if (timeUpdateInterval) {
                        clearInterval(timeUpdateInterval);
                        timeUpdateInterval = null;
                    }
                }
                
                function onPlayerReady(event) {
                    console.log('Player Ready');
                    isPlayerReady = true;
                    
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
                    
                    // Start updates only if video is playing
                    if (player.getPlayerState() === YT.PlayerState.PLAYING) {
                        startTimeUpdates();
                    }
                    
                    sendMessage({
                        'event': 'ready',
                        'availablePlaybackRates': player.getAvailablePlaybackRates(),
                        'availableQualityLevels': player.getAvailableQualityLevels()
                    });
                }
                
                function onPlayerStateChange(event) {
                    if (event.data === YT.PlayerState.PLAYING) {
                        startTimeUpdates();
                    } else {
                        stopTimeUpdates();
                    }
                    
                    sendMessage({
                        'event': 'stateChange',
                        'state': event.data
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
                
                // Optimized message sending
                const messageQueue = [];
                let isProcessingQueue = false;
                
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
                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify(message));
                    
                    // Process next message in next frame
                    requestAnimationFrame(processMessageQueue);
                }
                
                // Optimized event handling
                window.addEventListener('orientationchange', handleOrientationChange, eventListenerOpts);
                window.addEventListener('resize', handleOrientationChange, eventListenerOpts);
                
                function handleOrientationChange() {
                    requestAnimationFrame(() => {
                        const container = document.querySelector('.container');
                        const playerElement = document.getElementById('player');
                        
                        if (window.orientation === 90 || window.orientation === -90) {
                            container.style.cssText = 'padding-bottom: 0; height: 100vh;';
                            playerElement.style.cssText = 'width: 100vw; height: 100vh;';
                        } else {
                            container.style.cssText = 'padding-bottom: 56.25%; height: 0;';
                            playerElement.style.cssText = 'width: 100%; height: 100%;';
                        }
                    });
                }
                
                // Error handling
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
