import Foundation

struct YouTubePlayerHTML {
    static func generateHTML(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body { margin: 0; background-color: transparent; }
                .container { position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; }
                #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
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
                
                function onYouTubeIframeAPIReady() {
                    console.log('YouTube API Ready');
                    player = new YT.Player('player', {
                        videoId: '\(videoID)',
                        playerVars: {
                            'playsinline': 1,
                            'rel': 0,
                            'controls': 1,
                            'enablejsapi': 1,
                            'origin': window.location.origin,
                            'modestbranding': 1,
                            'fs': 1
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    console.log('Player Ready');
                    isPlayerReady = true;
                    startTimeUpdates();
                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                        'event': 'ready'
                    }));
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
                            window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                                'event': 'timeUpdate',
                                'time': currentTime
                            }));
                        } catch (error) {
                            console.error('Error updating time:', error);
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
                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                        'event': 'stateChange',
                        'state': event.data
                    }));
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
                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                        'event': 'error',
                        'error': errorMessage
                    }));
                }
                
                window.seekVideo = function(seconds) {
                    console.log('Seeking to:', seconds);
                    if (!player || !isPlayerReady) {
                        console.error('Player not ready');
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                            'event': 'error',
                            'error': 'Player not ready'
                        }));
                        return;
                    }
                    
                    try {
                        const targetTime = Math.round(seconds * 10) / 10;
                        player.seekTo(targetTime, true);
                        
                        if (player.getPlayerState() !== YT.PlayerState.PLAYING) {
                            player.playVideo();
                        }
                        
                        currentTime = targetTime;
                        
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                            'event': 'seeked',
                            'time': targetTime
                        }));
                    } catch (error) {
                        console.error('Seek error:', error);
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                            'event': 'error',
                            'error': 'Seek error: ' + error.message
                        }));
                    }
                };
                
                window.onerror = function(message, source, lineno, colno, error) {
                    console.error('JavaScript error:', message);
                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                        'event': 'error',
                        'error': 'JavaScript error: ' + message
                    }));
                    return false;
                };
            </script>
        </body>
        </html>
        """
    }
}
