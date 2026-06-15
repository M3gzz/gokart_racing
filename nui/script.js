// Select UI Views
const app = document.getElementById('app');
const viewBrowser = document.getElementById('view-browser');
const viewCreate = document.getElementById('view-create');
const viewRoom = document.getElementById('view-room');
const viewCreator = document.getElementById('view-creator');
const viewSetup = document.getElementById('view-setup');

// Select Form elements
const selectTrack = document.getElementById('select-track');
const inputLobbyName = document.getElementById('input-lobby-name');
const selectMaxPlayers = document.getElementById('select-max-players');
const selectKartModel = document.getElementById('select-kart-model');
const createLobbyForm = document.getElementById('create-lobby-form');

const createTrackForm = document.getElementById('create-track-form');
const inputTrackName = document.getElementById('input-track-name');
const inputTrackLaps = document.getElementById('input-track-laps');

// Betting Pool Elements
const inputBetAmount = document.getElementById('input-bet-amount');
const btnSubmitBet = document.getElementById('btn-submit-bet');
const roomTotalPool = document.getElementById('room-total-pool');

// Select List Containers
const lobbyListTbody = document.getElementById('lobby-list-tbody');
const noLobbiesDiv = document.getElementById('no-lobbies');
const roomMemberListDiv = document.getElementById('room-member-list');

// Select Room Details
const roomNameText = document.getElementById('room-name');
const roomTrackText = document.getElementById('room-track');
const roomStatusText = document.getElementById('room-status');
const roomPlayerCountText = document.getElementById('room-player-count');
const roomMaxPlayersText = document.getElementById('room-max-players');
const detailsTrackNameText = document.getElementById('details-track-name');
const detailsTrackLapsText = document.getElementById('details-track-laps');

// Buttons
const closeBtn = document.getElementById('close-btn');
const btnOpenCreate = document.getElementById('btn-open-create');
const btnBackBrowser = document.getElementById('btn-back-browser');
const btnCancelCreate = document.getElementById('btn-cancel-create');
const btnLeaveRoom = document.getElementById('btn-leave-room');
const btnStartRace = document.getElementById('btn-start-race');
const nonHostMsg = document.getElementById('non-host-msg');

const btnCreatorTab = document.getElementById('btn-creator-tab');
const btnBrowserTab = document.getElementById('btn-browser');
const btnBackCreator = document.getElementById('btn-back-creator');
const btnCancelCreator = document.getElementById('btn-cancel-creator');

// =========================================================================
// PHASE 2: HUD, COUNTDOWN, AND RESULTS ELEMENTS
// =========================================================================
const hudContainer = document.getElementById('hud-container');
const hudLapTime = document.getElementById('hud-lap-time');
const hudTotalTime = document.getElementById('hud-total-time');
const hudBestLap = document.getElementById('hud-best-lap');
const hudPosition = document.getElementById('hud-position');
const hudPositionSuffix = document.getElementById('hud-position-suffix');
const hudCurrentLap = document.getElementById('hud-current-lap');
const hudTotalLaps = document.getElementById('hud-total-laps');
const hudLeaderboardItems = document.getElementById('hud-leaderboard-items');

const countdownContainer = document.getElementById('countdown-container');
const countdownNumber = document.getElementById('countdown-number');

const resultsContainer = document.getElementById('results-container');
const resultsTrackName = document.getElementById('results-track-name');
const resultsRankingsList = document.getElementById('results-rankings-list');

let currentLobbyId = null;
let clientBestLap = 99999999;
let clientPlayerName = "";

// =========================================================================
// HELPER FUNCTIONS
// =========================================================================

// Switch active panel view
function switchView(viewName) {
    viewBrowser.classList.add('hidden');
    viewCreate.classList.add('hidden');
    viewRoom.classList.add('hidden');
    if (viewCreator) viewCreator.classList.add('hidden');
    if (viewSetup) viewSetup.classList.add('hidden');

    if (viewName === 'browser') {
        viewBrowser.classList.remove('hidden');
    } else if (viewName === 'create') {
        viewCreate.classList.remove('hidden');
    } else if (viewName === 'room') {
        viewRoom.classList.remove('hidden');
    } else if (viewName === 'creator') {
        if (viewCreator) viewCreator.classList.remove('hidden');
    } else if (viewName === 'setup') {
        if (viewSetup) viewSetup.classList.remove('hidden');
    }
}

// POST NUI Callbacks to FiveM Lua Client
function sendCallback(endpoint, data = {}) {
    fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data)
    }).catch(err => console.error(`Error sending NUI Callback (${endpoint}):`, err));
}

// Format milliseconds to MM:SS.hh (e.g. 01:23.45)
function formatTime(ms) {
    if (ms === undefined || ms === null || ms === 99999999 || ms === 0) return "--:--.--";
    
    const minutes = Math.floor(ms / 60000);
    const seconds = Math.floor((ms % 60000) / 1000);
    const hundredths = Math.floor((ms % 1000) / 10);

    const mStr = minutes.toString().padStart(2, '0');
    const sStr = seconds.toString().padStart(2, '0');
    const hStr = hundredths.toString().padStart(2, '0');

    return `${mStr}:${sStr}.${hStr}`;
}

// Convert numbers into ordinals (1st, 2nd, etc.)
function getOrdinalSuffix(i) {
    const j = i % 10, k = i % 100;
    if (j === 1 && k !== 11) return "ST";
    if (j === 2 && k !== 12) return "ND";
    if (j === 3 && k !== 13) return "RD";
    return "TH";
}

// HTML Escaper for security
function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
}

// =========================================================================
// WINDOW MESSAGE LISTENER (Lua -> NUI)
// =========================================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openUI':
            if (data.playerName) {
                clientPlayerName = data.playerName;
            }
            app.classList.remove('hidden');
            // Populate tracks select options
            if (data.tracks) {
                selectTrack.innerHTML = '';
                data.tracks.forEach(track => {
                    const opt = document.createElement('option');
                    opt.value = track.id;
                    opt.textContent = `${track.name} (${track.laps} laps - max ${track.maxSlots} p)`;
                    selectTrack.appendChild(opt);
                });
            }
            // Populate kart models options
            if (selectKartModel && data.karts) {
                selectKartModel.innerHTML = '';
                data.karts.forEach(kartModel => {
                    const opt = document.createElement('option');
                    opt.value = kartModel;
                    let displayName = kartModel;
                    if (kartModel === 'kart') displayName = 'Standard Kart';
                    else if (kartModel === 'veto') displayName = 'Veto Classic';
                    else if (kartModel === 'veto2') displayName = 'Veto Modern';
                    else {
                        displayName = kartModel.charAt(0).toUpperCase() + kartModel.slice(1);
                    }
                    opt.textContent = displayName;
                    selectKartModel.appendChild(opt);
                });
            }
            // Toggle create button and creator tab visibility based on admin status
            if (data.isAdmin) {
                btnOpenCreate.classList.remove('hidden');
                if (btnCreatorTab) btnCreatorTab.classList.remove('hidden');
            } else {
                btnOpenCreate.classList.add('hidden');
                if (btnCreatorTab) btnCreatorTab.classList.add('hidden');
            }
            // Reset active tabs
            if (btnBrowserTab) btnBrowserTab.classList.add('active');
            if (btnCreatorTab) btnCreatorTab.classList.remove('active');
            switchView('browser');
            break;

        case 'closeUI':
            app.classList.add('hidden');
            break;

        case 'updateLobbies':
            renderLobbyList(data.lobbies);
            break;

        case 'joinLobbyRoom':
            clientBestLap = 99999999; // Reset lap time on join
            setupLobbyRoom(data.lobby, data.isHost);
            switchView('room');
            break;

        case 'updateLobbyRoom':
            if (currentLobbyId === null) {
                clientBestLap = 99999999;
            }
            setupLobbyRoom(data.lobby, data.isHost);
            switchView('room');
            break;

        case 'exitLobbyRoom':
            currentLobbyId = null;
            switchView('browser');
            break;

        // PHASE 2 ACTIONS
        case 'startRaceCountdown':
            app.classList.add('hidden'); // Close lobby panel
            triggerCountdown(data.duration);
            break;

        case 'updateRaceHUD':
            updateRaceHUD(data);
            break;

        case 'finishRace':
            clientBestLap = data.bestLap;
            hudBestLap.textContent = formatTime(clientBestLap);
            break;

        case 'showRaceResults':
            hudContainer.classList.add('hidden');
            showRaceResults(data.rankings);
            break;

        case 'hideRaceHUD':
            hudContainer.classList.add('hidden');
            countdownContainer.classList.add('hidden');
            resultsContainer.classList.add('hidden');
            break;

        case 'showCreatorHUD':
            const creatorHud = document.getElementById('creator-hud');
            if (creatorHud) {
                const hudTrackName = document.getElementById('creator-hud-track-name');
                const hudGrids = document.getElementById('creator-hud-grids');
                const hudCheckpoints = document.getElementById('creator-hud-checkpoints');
                if (hudTrackName) hudTrackName.textContent = data.name.toUpperCase();
                if (hudGrids) hudGrids.textContent = `0 / 8`;
                if (hudCheckpoints) hudCheckpoints.textContent = `0`;
                creatorHud.classList.remove('hidden');
            }
            break;

        case 'updateCreatorHUD':
            const hudGrids = document.getElementById('creator-hud-grids');
            const hudCheckpoints = document.getElementById('creator-hud-checkpoints');
            if (hudGrids) hudGrids.textContent = `${data.grids} / 8`;
            if (hudCheckpoints) hudCheckpoints.textContent = `${data.checkpoints}`;
            break;

        case 'hideCreatorHUD':
            const creatorHudHide = document.getElementById('creator-hud');
            if (creatorHudHide) {
                creatorHudHide.classList.add('hidden');
            }
            break;
            
        case 'openSetupUI':
            app.classList.remove('hidden');
            if (data.coords) {
                document.getElementById('setup-coords-x').textContent = data.coords.x;
                document.getElementById('setup-coords-y').textContent = data.coords.y;
                document.getElementById('setup-coords-z').textContent = data.coords.z;
                document.getElementById('setup-coords-h').textContent = data.coords.heading;
            }
            switchView('setup');
            break;
    }
});

// Render the main lobby list table
function renderLobbyList(lobbies) {
    lobbyListTbody.innerHTML = '';

    if (!lobbies || lobbies.length === 0) {
        noLobbiesDiv.classList.remove('hidden');
        return;
    }

    noLobbiesDiv.classList.add('hidden');

    lobbies.forEach(lobby => {
        const tr = document.createElement('tr');
        
        const statusClass = lobby.status === 'waiting' ? 'status-waiting' : 'status-racing';
        const displayStatus = lobby.status === 'waiting' ? 'Waiting' : 'Racing';

        const isFull = lobby.playerCount >= lobby.maxPlayers;
        const canJoin = lobby.status === 'waiting' && !isFull;

        tr.innerHTML = `
            <td><strong>${escapeHtml(lobby.name)}</strong></td>
            <td>${escapeHtml(lobby.trackName)}</td>
            <td>${escapeHtml(lobby.hostName)}</td>
            <td>${lobby.playerCount} / ${lobby.maxPlayers}</td>
            <td><span class="status-badge ${statusClass}">${displayStatus}</span></td>
            <td class="action-cell">
                ${canJoin 
                    ? `<button class="btn-table-join" onclick="joinLobby('${lobby.id}')">Join</button>`
                    : `<button class="btn-table-join" style="opacity:0.4; pointer-events:none;">${isFull ? 'Full' : 'In Progress'}</button>`
                }
            </td>
        `;
        lobbyListTbody.appendChild(tr);
    });
}

// Setup Lobby Details inside Room
function setupLobbyRoom(lobby, isHost) {
    currentLobbyId = lobby.id;
    roomNameText.textContent = lobby.name;
    roomTrackText.innerHTML = `<i class="fa-solid fa-map-location-dot"></i> ${lobby.trackName}`;
    roomStatusText.textContent = lobby.status.toUpperCase();

    roomStatusText.className = 'room-status-badge';
    if (lobby.status === 'waiting') {
        roomStatusText.classList.add('status-waiting');
    } else {
        roomStatusText.classList.add('status-racing');
    }

    roomPlayerCountText.textContent = lobby.players.length;
    roomMaxPlayersText.textContent = lobby.maxPlayers;

    detailsTrackNameText.textContent = lobby.trackName;
    detailsTrackLapsText.textContent = `${lobby.trackName.includes('Redwood') ? 2 : 3} Laps`;

    if (roomTotalPool) {
        roomTotalPool.textContent = `$${lobby.betPool || 0}`;
    }

    // Render Members list
    roomMemberListDiv.innerHTML = '';
    lobby.players.forEach(player => {
        const card = document.createElement('div');
        card.className = 'member-card';

        const isPlayerHost = lobby.host === player.citizenid;

        card.innerHTML = `
            <div class="member-info">
                <div class="member-avatar">
                    <i class="fa-solid fa-helmet-safety"></i>
                </div>
                <span class="member-name">${escapeHtml(player.name)}</span>
            </div>
            <div class="member-badges">
                ${player.bet ? `<span class="bet-badge"><i class="fa-solid fa-coins"></i> $${player.bet}</span>` : ''}
                ${isPlayerHost ? '<span class="host-badge">HOST</span>' : ''}
            </div>
        `;
        roomMemberListDiv.appendChild(card);
    });

    // Render Bets list
    const roomBetsList = document.getElementById('room-bets-list');
    if (roomBetsList) {
        roomBetsList.innerHTML = '';
        let hasBets = false;
        lobby.players.forEach(player => {
            if (player.bet && player.bet > 0) {
                hasBets = true;
                const row = document.createElement('div');
                row.className = 'bet-row';
                row.innerHTML = `
                    <span class="bet-player-name">${escapeHtml(player.name)}</span>
                    <span class="bet-player-amount">$${player.bet}</span>
                `;
                roomBetsList.appendChild(row);
            }
        });

        if (!hasBets) {
            roomBetsList.innerHTML = '<div class="no-bets-hint">No bets placed yet</div>';
        }
    }

    // Toggle Host and Player controls
    const btnCloseLobby = document.getElementById('btn-close-lobby');
    if (isHost) {
        btnStartRace.classList.remove('hidden');
        if (btnCloseLobby) btnCloseLobby.classList.remove('hidden');
        nonHostMsg.classList.add('hidden');
    } else {
        btnStartRace.classList.add('hidden');
        if (btnCloseLobby) btnCloseLobby.classList.add('hidden');
        nonHostMsg.classList.remove('hidden');
    }
}

// Global Join Function called from inline HTML onClick
window.joinLobby = function(lobbyId) {
    sendCallback('joinLobby', { lobbyId: lobbyId });
};

// =========================================================================
// PHASE 2: RACING LIFE-CYCLE UI CONTROLS
// =========================================================================

// Sequence the starting lights countdown overlay
function triggerCountdown(duration) {
    countdownContainer.classList.remove('hidden');
    countdownNumber.classList.remove('go-text');
    
    let count = duration;
    countdownNumber.textContent = count;
    
    const interval = setInterval(() => {
        count--;
        if (count > 0) {
            countdownNumber.textContent = count;
        } else if (count === 0) {
            countdownNumber.textContent = "GO!";
            countdownNumber.classList.add('go-text');
        } else {
            clearInterval(interval);
            countdownContainer.classList.add('hidden');
            hudContainer.classList.remove('hidden');
        }
    }, 1000);
}

// Render dynamic HUD statistics
function updateRaceHUD(data) {
    hudPosition.textContent = data.position;
    hudPositionSuffix.textContent = getOrdinalSuffix(data.position);
    hudCurrentLap.textContent = data.lap;
    hudTotalLaps.textContent = data.totalLaps;
    
    hudLapTime.textContent = formatTime(data.lapTime);
    hudTotalTime.textContent = formatTime(data.raceTime);

    // Populate HUD Leaderboard positions list
    hudLeaderboardItems.innerHTML = '';
    if (data.leaderboard && data.leaderboard.length > 0) {
        data.leaderboard.forEach(racer => {
            const isSelf = racer.name === clientPlayerName;
            
            const card = document.createElement('div');
            card.className = `hud-racer-card ${isSelf ? 'self-card' : ''}`;
            
            card.innerHTML = `
                <div class="racer-rank-name">
                    <span class="rank-num">${racer.position}</span>
                    <span class="rank-name">${escapeHtml(racer.name)}</span>
                </div>
                <div class="racer-lap-status ${racer.finished ? 'racer-finished' : ''}">
                    ${racer.finished ? 'Finished' : `L${racer.lap}`}
                </div>
            `;
            hudLeaderboardItems.appendChild(card);
        });
    }
}

// Show the final standings scoreboard screen
function showRaceResults(rankings) {
    resultsContainer.classList.remove('hidden');
    resultsTrackName.textContent = detailsTrackNameText.textContent;
    resultsRankingsList.innerHTML = '';
    
    rankings.forEach(player => {
        const row = document.createElement('div');
        row.className = `result-row pos-${player.position}`;
        
        row.innerHTML = `
            <div class="result-driver-info">
                <div class="result-pos-badge">${player.position}</div>
                <span class="result-name">${escapeHtml(player.name)}</span>
            </div>
            <div class="result-stats-block">
                <span class="result-time">${formatTime(player.totalTime)}</span>
                <span class="result-best-lap">Best Lap: ${formatTime(player.bestLap)}</span>
            </div>
        `;
        resultsRankingsList.appendChild(row);
    });
}

// =========================================================================
// EVENT HANDLERS
// =========================================================================

closeBtn.addEventListener('click', () => {
    sendCallback('close');
});

btnOpenCreate.addEventListener('click', () => {
    inputLobbyName.value = '';
    switchView('create');
});

btnBackBrowser.addEventListener('click', () => {
    switchView('browser');
});

btnCancelCreate.addEventListener('click', () => {
    switchView('browser');
});

createLobbyForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = inputLobbyName.value.trim();
    const track = selectTrack.value;
    const maxPlayers = parseInt(selectMaxPlayers.value);
    const kartModel = selectKartModel ? selectKartModel.value : 'kart';

    if (name) {
        sendCallback('createLobby', {
            name: name,
            track: track,
            maxPlayers: maxPlayers,
            kartModel: kartModel
        });
    }
});

btnCreatorTab.addEventListener('click', () => {
    btnBrowserTab.classList.remove('active');
    btnCreatorTab.classList.add('active');
    switchView('creator');
});

btnBrowserTab.addEventListener('click', () => {
    btnCreatorTab.classList.remove('active');
    btnBrowserTab.classList.add('active');
    switchView('browser');
});

btnBackCreator.addEventListener('click', () => {
    btnCreatorTab.classList.remove('active');
    btnBrowserTab.classList.add('active');
    switchView('browser');
});

btnCancelCreator.addEventListener('click', () => {
    btnCreatorTab.classList.remove('active');
    btnBrowserTab.classList.add('active');
    switchView('browser');
});

createTrackForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = inputTrackName.value.trim();
    const laps = parseInt(inputTrackLaps.value) || 3;

    if (name) {
        sendCallback('startTrackCreator', {
            name: name,
            laps: laps
        });
        // Close NUI
        app.classList.add('hidden');
        sendCallback('close');
    }
});

btnLeaveRoom.addEventListener('click', () => {
    if (currentLobbyId) {
        sendCallback('leaveLobby', { lobbyId: currentLobbyId });
    }
});

btnStartRace.addEventListener('click', () => {
    sendCallback('startRace');
});

if (btnSubmitBet) {
    btnSubmitBet.addEventListener('click', () => {
        const amount = parseInt(inputBetAmount.value);
        if (isNaN(amount) || amount <= 0) {
            sendCallback('notify', { text: 'Invalid bet amount!', type: 'error' });
            return;
        }
        sendCallback('placeBet', { amount: amount });
        inputBetAmount.value = '';
    });
}

// Dismiss results container manually
function dismissResults() {
    if (!resultsContainer.classList.contains('hidden')) {
        resultsContainer.classList.add('hidden');
        sendCallback('dismissResults');
    }
}

// Click anywhere on results container to exit immediately
resultsContainer.addEventListener('click', () => {
    dismissResults();
});

// Close UI on ESC keypress, or dismiss results on ESC/Space/Enter
document.addEventListener('keydown', (e) => {
    if (!resultsContainer.classList.contains('hidden')) {
        if (e.key === 'Escape' || e.key === ' ' || e.key === 'Enter') {
            e.preventDefault();
            dismissResults();
        }
    } else {
        if (e.key === 'Escape') {
            const isSetupOpen = !viewSetup.classList.contains('hidden');
            if (isSetupOpen) {
                sendCallback('closeSetup');
            } else {
                sendCallback('close');
            }
        }
    }
});

// Setup NPC Event Listeners
const setupNPCForm = document.getElementById('setup-npc-form');
const btnPreviewNPC = document.getElementById('btn-preview-npc');
const btnCancelSetup = document.getElementById('btn-cancel-setup');
const btnCloseLobby = document.getElementById('btn-close-lobby');
const btnForceLeave = document.getElementById('btn-force-leave');

if (btnPreviewNPC) {
    btnPreviewNPC.addEventListener('click', () => {
        const model = document.getElementById('select-setup-model').value;
        const scenario = document.getElementById('select-setup-scenario').value;
        sendCallback('previewNPC', { model: model, scenario: scenario });
    });
}

if (setupNPCForm) {
    setupNPCForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const model = document.getElementById('select-setup-model').value;
        const scenario = document.getElementById('select-setup-scenario').value;
        sendCallback('saveNPC', { model: model, scenario: scenario });
        app.classList.add('hidden');
    });
}

if (btnCancelSetup) {
    btnCancelSetup.addEventListener('click', () => {
        sendCallback('closeSetup');
        app.classList.add('hidden');
    });
}

if (btnCloseLobby) {
    btnCloseLobby.addEventListener('click', () => {
        if (currentLobbyId) {
            sendCallback('deleteLobby');
        }
    });
}

if (btnForceLeave) {
    btnForceLeave.addEventListener('click', () => {
        sendCallback('forceLeaveSession');
        app.classList.add('hidden');
    });
}
