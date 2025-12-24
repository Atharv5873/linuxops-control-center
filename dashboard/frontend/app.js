// ==========================================
// LINUXOPS CONTROL CENTER - DASHBOARD APP
// ==========================================

const API_BASE = 'http://localhost:8000/api';

// Chart instances
let cpuChart, memoryChart, diskChart;

// Data buffers for charts (keep last 20 points)
const MAX_DATA_POINTS = 20;

// ==========================================
// UTILITY FUNCTIONS
// ==========================================

/**
 * Safely fetch data from API with error handling
 */
async function fetchAPI(endpoint) {
    try {
        const response = await fetch(`${API_BASE}${endpoint}`);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error(`Error fetching ${endpoint}:`, error);
        return null;
    }
}

/**
 * Format timestamp to readable format
 */
function formatTime(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit',
        second: '2-digit'
    });
}

/**
 * Format uptime seconds to human readable
 */
function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (days > 0) {
        return `${days}d ${hours}h ${minutes}m`;
    } else if (hours > 0) {
        return `${hours}h ${minutes}m`;
    } else {
        return `${minutes}m`;
    }
}

/**
 * Update last refresh timestamp
 */
function updateLastRefresh() {
    const now = new Date();
    document.getElementById('lastUpdate').textContent = now.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}

// ==========================================
// SYSTEM HEALTH DATA LOADING
// ==========================================

/**
 * Load and display system health metrics
 */
async function loadHealth() {
    const data = await fetchAPI('/health');
    
    if (!data || !data.data) {
        console.error('No health data received');
        return;
    }
    
    const health = data.data;
    
    // Update CPU metrics
    if (health.cpu) {
        document.getElementById('cpuValue').textContent = `${health.cpu.usage_percent}%`;
        document.getElementById('cpuBar').style.width = `${health.cpu.usage_percent}%`;
        
        if (health.cpu.load_avg) {
            document.getElementById('loadAvg').textContent = 
                `${health.cpu.load_avg['1m']} / ${health.cpu.load_avg['5m']} / ${health.cpu.load_avg['15m']}`;
        }
    }
    
    // Update Memory metrics
    if (health.memory) {
        document.getElementById('memoryValue').textContent = `${health.memory.used_percent}%`;
        document.getElementById('memoryBar').style.width = `${health.memory.used_percent}%`;
        document.getElementById('memoryDetail').textContent = 
            `${health.memory.used_mb} / ${health.memory.total_mb} MB`;
    }
    
    // Update Disk metrics
    if (health.disk) {
        document.getElementById('diskValue').textContent = `${health.disk.used_percent}%`;
        document.getElementById('diskBar').style.width = `${health.disk.used_percent}%`;
        document.getElementById('diskDetail').textContent = 
            `${health.disk.used_gb} / ${health.disk.total_gb} GB`;
    }
    
    // Update Uptime
    if (health.system && health.system.uptime_seconds) {
        document.getElementById('uptimeValue').textContent = formatUptime(health.system.uptime_seconds);
    }
    
    // Update Hostname
    if (health.hostname) {
        document.getElementById('hostname').textContent = health.hostname;
    }
    
    // Update Services
    if (health.services) {
        updateServices(health.services);
    }
    
    // Update Top Processes
    if (health.processes) {
        updateProcesses(health.processes);
    }
    
    // Update Charts
    updateCharts(health);
}

/**
 * Update service status badges
 */
function updateServices(services) {
    const serviceMap = {
        'ssh': 'sshService',
        'nginx': 'nginxService',
        'fail2ban': 'fail2banService',
        'ufw': 'ufwService'
    };
    
    Object.entries(serviceMap).forEach(([serviceName, elementId]) => {
        const element = document.getElementById(elementId);
        if (element && services[serviceName]) {
            const status = services[serviceName];
            const statusElement = element.querySelector('.service-status');
            
            // Remove old classes
            element.classList.remove('active', 'inactive');
            
            // Add new class
            if (status === 'active') {
                element.classList.add('active');
                statusElement.textContent = 'Active';
            } else {
                element.classList.add('inactive');
                statusElement.textContent = 'Inactive';
            }
        }
    });
}

/**
 * Update top processes lists
 */
function updateProcesses(processes) {
    // Top CPU
    if (processes.top_cpu) {
        const cpuList = document.getElementById('topCpu');
        cpuList.innerHTML = '';
        
        processes.top_cpu.slice(0, 5).forEach(proc => {
            const item = document.createElement('div');
            item.className = 'process-item';
            item.innerHTML = `
                <div>
                    <span class="process-name">${proc.name}</span>
                    <span class="process-pid">(PID: ${proc.pid})</span>
                </div>
                <span class="process-value">${proc.cpu_percent}%</span>
            `;
            cpuList.appendChild(item);
        });
    }
    
    // Top Memory
    if (processes.top_memory) {
        const memList = document.getElementById('topMemory');
        memList.innerHTML = '';
        
        processes.top_memory.slice(0, 5).forEach(proc => {
            const item = document.createElement('div');
            item.className = 'process-item';
            item.innerHTML = `
                <div>
                    <span class="process-name">${proc.name}</span>
                    <span class="process-pid">(PID: ${proc.pid})</span>
                </div>
                <span class="process-value">${proc.mem_percent}%</span>
            `;
            memList.appendChild(item);
        });
    }
}

// ==========================================
// CHARTS
// ==========================================

/**
 * Initialize Chart.js charts
 */
function initCharts() {
    const commonOptions = {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
            legend: {
                display: false
            }
        },
        scales: {
            x: {
                display: true,
                grid: {
                    color: 'rgba(255, 255, 255, 0.05)'
                },
                ticks: {
                    color: '#9ca3af',
                    maxRotation: 0,
                    autoSkip: true,
                    maxTicksLimit: 10
                }
            },
            y: {
                beginAtZero: true,
                max: 100,
                grid: {
                    color: 'rgba(255, 255, 255, 0.05)'
                },
                ticks: {
                    color: '#9ca3af',
                    callback: function(value) {
                        return value + '%';
                    }
                }
            }
        },
        interaction: {
            intersect: false,
            mode: 'index'
        }
    };
    
    // CPU Chart
    cpuChart = new Chart(document.getElementById('cpuChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'CPU Usage',
                data: [],
                borderColor: '#ef4444',
                backgroundColor: 'rgba(239, 68, 68, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.4,
                pointRadius: 0,
                pointHoverRadius: 4,
                pointBackgroundColor: '#ef4444'
            }]
        },
        options: commonOptions
    });
    
    // Memory Chart
    memoryChart = new Chart(document.getElementById('memoryChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Memory Usage',
                data: [],
                borderColor: '#8b5cf6',
                backgroundColor: 'rgba(139, 92, 246, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.4,
                pointRadius: 0,
                pointHoverRadius: 4,
                pointBackgroundColor: '#8b5cf6'
            }]
        },
        options: commonOptions
    });
    
    // Disk Chart
    diskChart = new Chart(document.getElementById('diskChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Disk Usage',
                data: [],
                borderColor: '#06b6d4',
                backgroundColor: 'rgba(6, 182, 212, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.4,
                pointRadius: 0,
                pointHoverRadius: 4,
                pointBackgroundColor: '#06b6d4'
            }]
        },
        options: commonOptions
    });
}

/**
 * Update charts with new data
 */
function updateCharts(health) {
    if (!cpuChart || !memoryChart || !diskChart) {
        return;
    }
    
    const currentTime = new Date().toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit' 
    });
    
    // Helper function to update a chart
    function updateChart(chart, value) {
        // Add new data
        chart.data.labels.push(currentTime);
        chart.data.datasets[0].data.push(value);
        
        // Remove old data if exceeds limit
        if (chart.data.labels.length > MAX_DATA_POINTS) {
            chart.data.labels.shift();
            chart.data.datasets[0].data.shift();
        }
        
        chart.update('none'); // Update without animation for better performance
    }
    
    // Update each chart
    if (health.cpu && health.cpu.usage_percent !== undefined) {
        updateChart(cpuChart, health.cpu.usage_percent);
    }
    
    if (health.memory && health.memory.used_percent !== undefined) {
        updateChart(memoryChart, health.memory.used_percent);
    }
    
    if (health.disk && health.disk.used_percent !== undefined) {
        updateChart(diskChart, health.disk.used_percent);
    }
}

// ==========================================
// ALERTS
// ==========================================

/**
 * Load and display alerts
 */
async function loadAlerts() {
    const data = await fetchAPI('/alerts');
    
    if (!data || !data.alerts) {
        console.error('No alerts data received');
        return;
    }
    
    const alertsTable = document.getElementById('alertsTableBody');
    const alertCount = document.getElementById('alertCount');
    
    // Update count
    alertCount.textContent = data.count || data.alerts.length;
    
    // Clear existing rows
    alertsTable.innerHTML = '';
    
    if (data.alerts.length === 0) {
        alertsTable.innerHTML = '<tr><td colspan="6" class="no-data">No alerts recorded</td></tr>';
        return;
    }
    
    // Add alert rows
    data.alerts.forEach(alert => {
        const row = document.createElement('tr');
        
        // Determine state class
        let stateClass = 'alert';
        if (alert.state === 'RECOVERED') {
            stateClass = 'recovered';
        } else if (alert.state.includes('RECOVERY_FAILED')) {
            stateClass = 'recovery-failed';
        }
        
        row.innerHTML = `
            <td><strong>${alert.alert}</strong></td>
            <td><span class="alert-state ${stateClass}">${alert.state}</span></td>
            <td>${alert.host}</td>
            <td>${alert.value}</td>
            <td>${alert.threshold}</td>
            <td>${formatTime(alert.timestamp)}</td>
        `;
        
        alertsTable.appendChild(row);
    });
}

// ==========================================
// SELF-HEALING
// ==========================================

/**
 * Load and display self-healing events
 */
async function loadHealing() {
    const data = await fetchAPI('/healing');
    
    if (!data || !data.events) {
        console.error('No healing data received');
        return;
    }
    
    const healingLog = document.getElementById('healingLog');
    const healingCount = document.getElementById('healingCount');
    
    // Update count
    healingCount.textContent = data.count || data.events.length;
    
    // Clear existing logs
    healingLog.innerHTML = '';
    
    if (data.events.length === 0) {
        healingLog.innerHTML = '<div class="log-entry">No self-healing events recorded</div>';
        return;
    }
    
    // Add log entries (newest first)
    data.events.forEach(event => {
        const entry = document.createElement('div');
        entry.className = 'log-entry';
        
        // Color code based on content
        if (event.includes('successful') || event.includes('SUCCESS')) {
            entry.classList.add('success');
        } else if (event.includes('failed') || event.includes('ERROR')) {
            entry.classList.add('error');
        }
        
        entry.textContent = event;
        healingLog.appendChild(entry);
    });
}

// ==========================================
// MAIN REFRESH LOGIC
// ==========================================

/**
 * Refresh all dashboard data
 */
async function refreshDashboard() {
    try {
        await Promise.all([
            loadHealth(),
            loadAlerts(),
            loadHealing()
        ]);
        
        updateLastRefresh();
    } catch (error) {
        console.error('Error refreshing dashboard:', error);
    }
}

// ==========================================
// INITIALIZATION
// ==========================================

/**
 * Initialize dashboard on page load
 */
document.addEventListener('DOMContentLoaded', () => {
    console.log('LinuxOps Control Center Dashboard Initializing...');
    
    // Initialize charts
    initCharts();
    
    // Initial data load
    refreshDashboard();
    
    // Set up auto-refresh every 5 seconds
    setInterval(refreshDashboard, 5000);
    
    console.log('Dashboard initialized successfully');
});

// Handle page visibility changes to pause/resume updates
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        console.log('Dashboard paused (tab hidden)');
    } else {
        console.log('Dashboard resumed');
        refreshDashboard();
    }
});
