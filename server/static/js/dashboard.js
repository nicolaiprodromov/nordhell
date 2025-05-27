let refreshInterval;

function showToast(title, message, type = 'info') {
    const toast = document.getElementById('toast');
    const toastTitle = document.getElementById('toastTitle');
    const toastMessage = document.getElementById('toastMessage');
    const toastIcon = document.getElementById('toastIcon');
    
    toastTitle.textContent = title;
    toastMessage.textContent = message;
    
    // Update icon and color based on type
    const iconColors = {
        'success': 'text-green-400',
        'error': 'text-red-400',
        'info': 'text-blue-400'
    };
    
    toastIcon.className = `w-6 h-6 ${iconColors[type] || iconColors.info}`;
    
    // Show toast
    toast.classList.remove('translate-x-full');
    
    // Hide after 3 seconds
    setTimeout(() => {
        toast.classList.add('translate-x-full');
    }, 3000);
}

async function refreshStatus() {
    try {
        const response = await fetch('/status');
        const data = await response.json();
        
        // Update total memory
        document.getElementById('totalMemory').textContent = `${data.total_memory_mb} MB`;
        
        // Update table
        const tbody = document.getElementById('tunnelsTableBody');
        tbody.innerHTML = '';
        
        data.tunnels.forEach(tunnel => {
            const row = document.createElement('tr');
            row.className = 'hover:bg-gray-700 transition-colors';
            
            const statusClass = tunnel.status === 'up' ? 'text-green-400' : 'text-red-400';
            const statusIcon = tunnel.status === 'up' ? 'circle-check' : 'circle-x';
            
            row.innerHTML = `
                <td class="px-6 py-4 whitespace-nowrap font-medium">${tunnel.tunnel}</td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <code class="bg-gray-700 px-2 py-1 rounded text-sm">${tunnel.port}</code>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <span class="flex items-center space-x-2 ${statusClass}">
                        <i data-lucide="${statusIcon}" class="w-4 h-4"></i>
                        <span class="${tunnel.status === 'up' ? 'pulse-slow' : ''}">${tunnel.status.toUpperCase()}</span>
                    </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">${tunnel.time_alive}</td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm">
                        <div class="flex items-center space-x-1">
                            <i data-lucide="map-pin" class="w-3 h-3 text-gray-500"></i>
                            <span>${tunnel.entrypoint}</span>
                        </div>
                        <div class="text-xs text-gray-500">${tunnel.entrypoint_ip}</div>
                    </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm">
                        <div class="flex items-center space-x-1">
                            <i data-lucide="globe" class="w-3 h-3 text-gray-500"></i>
                            <span>${tunnel.exitpoint}</span>
                        </div>
                        <div class="text-xs text-gray-500">${tunnel.exitpoint_ip}</div>
                    </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <span class="bg-gray-700 px-2 py-1 rounded text-sm">${tunnel.memory}</span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <button onclick="stopSingleTunnel(${tunnel.tunnel_id})" 
                            class="bg-red-600 hover:bg-red-700 px-3 py-1 rounded text-sm transition-all">
                        Stop
                    </button>
                </td>
            `;
            
            tbody.appendChild(row);
        });
        
        // Re-initialize Lucide icons
        lucide.createIcons();
        
    } catch (error) {
        showToast('Error', 'Failed to refresh status', 'error');
        console.error('Error:', error);
    }
}

async function startTunnel() {
    const tunnelId = document.getElementById('startTunnelId').value || '0';
    
    try {
        const response = await fetch('/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tunnel_id: tunnelId })
        });
        
        if (response.ok) {
            showToast('Success', `Started tunnel ${tunnelId}`, 'success');
            setTimeout(refreshStatus, 1000);
        } else {
            const error = await response.json();
            showToast('Error', error.detail || 'Failed to start tunnel', 'error');
        }
    } catch (error) {
        showToast('Error', 'Network error', 'error');
    }
}

async function stopTunnel() {
    const tunnelId = document.getElementById('stopTunnelId').value;
    if (!tunnelId) return;
    
    try {
        const response = await fetch('/stop', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tunnel_id: tunnelId })
        });
        
        if (response.ok) {
            showToast('Success', `Stopped tunnel ${tunnelId}`, 'success');
            setTimeout(refreshStatus, 1000);
        } else {
            const error = await response.json();
            showToast('Error', error.detail || 'Failed to stop tunnel', 'error');
        }
    } catch (error) {
        showToast('Error', 'Network error', 'error');
    }
}

async function stopSingleTunnel(tunnelId) {
    try {
        const response = await fetch('/stop', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tunnel_id: tunnelId.toString() })
        });
        
        if (response.ok) {
            showToast('Success', `Stopped tunnel ${tunnelId}`, 'success');
            setTimeout(refreshStatus, 1000);
        } else {
            const error = await response.json();
            showToast('Error', error.detail || 'Failed to stop tunnel', 'error');
        }
    } catch (error) {
        showToast('Error', 'Network error', 'error');
    }
}

async function replaceTunnel() {
    const stopId = document.getElementById('replaceStop').value;
    const startId = document.getElementById('replaceStart').value;
    
    if (!stopId || !startId) {
        showToast('Error', 'Please enter both tunnel IDs', 'error');
        return;
    }
    
    try {
        const response = await fetch('/replace', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                stop_tunnel: parseInt(stopId),
                start_tunnel: parseInt(startId)
            })
        });
        
        if (response.ok) {
            showToast('Success', `Replaced tunnel ${stopId} with ${startId}`, 'success');
            setTimeout(refreshStatus, 1000);
        } else {
            const error = await response.json();
            showToast('Error', error.detail || 'Failed to replace tunnel', 'error');
        }
    } catch (error) {
        showToast('Error', 'Network error', 'error');
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    lucide.createIcons();
    refreshStatus();
    // Auto-refresh every 30 seconds
    refreshInterval = setInterval(refreshStatus, 30000);
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (refreshInterval) clearInterval(refreshInterval);
});
