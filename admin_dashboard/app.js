// API Base URL config
const API_BASE = window.location.origin.includes('localhost') || window.location.origin.includes('127.0.0.1')
    ? window.location.origin
    : 'http://127.0.0.1:8000';

let adminToken = localStorage.getItem('adminToken') || '';
let adminCollege = localStorage.getItem('adminCollege') || '';
let adminEmail = localStorage.getItem('adminEmail') || '';
let currentBuildings = [];

// DOM Elements
const loginContainer = document.getElementById('login-container');
const appContainer = document.getElementById('app-container');
const loginForm = document.getElementById('login-form');
const loginEmail = document.getElementById('login-email');
const loginPassword = document.getElementById('login-password');
const logoutBtn = document.getElementById('logout-btn');
const timeDisplay = document.getElementById('time-display');

// Profile Elements
const adminCollegeEl = document.getElementById('admin-college');
const adminEmailEl = document.getElementById('admin-email');

// Navigation Tabs
const navItems = document.querySelectorAll('.nav-item');
const tabPanes = document.querySelectorAll('.tab-pane');
const pageTitle = document.getElementById('page-title');

// Stats Elements
const statUsers = document.getElementById('stat-users');
const statRestaurants = document.getElementById('stat-restaurants');
const statOrders = document.getElementById('stat-orders');
const statEarnings = document.getElementById('stat-earnings');

// Buildings Elements
const addBuildingForm = document.getElementById('add-building-form');
const bName = document.getElementById('b-name');
const bGender = document.getElementById('b-gender');
const buildingsList = document.getElementById('buildings-list');
const buildingsCount = document.getElementById('buildings-count');

// Restaurants Elements
const restaurantsList = document.getElementById('restaurants-list');
const addRestaurantBtn = document.getElementById('add-restaurant-btn');
const restaurantModal = document.getElementById('restaurant-modal');
const restaurantForm = document.getElementById('restaurant-form');
const modalTitle = document.getElementById('modal-title');
const editRestId = document.getElementById('edit-rest-id');
const restName = document.getElementById('rest-name');
const restEmail = document.getElementById('rest-email');
const restPassword = document.getElementById('rest-password');
const passwordGroup = document.getElementById('password-group');
const restDesc = document.getElementById('rest-desc');
const restCuisine = document.getElementById('rest-cuisine');
const restPhone = document.getElementById('rest-phone');
const restAddress = document.getElementById('rest-address');
const statusToggleGroup = document.getElementById('status-toggle-group');
const restIsOpen = document.getElementById('rest-is-open');

// App Initialization
document.addEventListener('DOMContentLoaded', () => {
    updateTime();
    setInterval(updateTime, 60000);
    
    if (adminToken) {
        showApp();
    } else {
        showLogin();
    }
});

function updateTime() {
    const now = new Date();
    const formatted = now.toISOString().replace('T', ' ').substring(0, 16);
    timeDisplay.textContent = formatted;
}

// Show/Hide Containers
function showLogin() {
    loginContainer.style.display = 'flex';
    appContainer.style.display = 'none';
}

function showApp() {
    loginContainer.style.display = 'none';
    appContainer.style.display = 'grid';
    
    adminCollegeEl.textContent = adminCollege;
    adminEmailEl.textContent = adminEmail;
    
    // Load default tab
    switchTab('stats-tab');
}

// Toast Notifications Helper
function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    let iconClass = 'fa-circle-info';
    if (type === 'success') iconClass = 'fa-circle-check';
    if (type === 'error') iconClass = 'fa-circle-exclamation';
    
    toast.innerHTML = `<i class="fa-solid ${iconClass}"></i> <span>${message}</span>`;
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s reverse';
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}

// API Helper fetch Wrapper
async function apiCall(endpoint, method = 'GET', body = null, isMultipart = false) {
    const headers = {};
    if (adminToken) {
        headers['Authorization'] = `Bearer ${adminToken}`;
    }
    
    let options = { method, headers };
    
    if (body) {
        if (isMultipart) {
            options.body = body;
        } else {
            headers['Content-Type'] = 'application/json';
            options.body = JSON.stringify(body);
        }
    }
    
    try {
        const response = await fetch(`${API_BASE}${endpoint}`, options);
        if (response.status === 401) {
            // Token expired or invalid
            handleLogout();
            throw new Error('Session expired. Please log in again.');
        }
        
        const data = await response.json();
        if (!response.ok) {
            throw new Error(data.detail || 'An error occurred');
        }
        return data;
    } catch (error) {
        showToast(error.message, 'error');
        throw error;
    }
}

// Login Handler
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = loginEmail.value.trim();
    const password = loginPassword.value;
    
    try {
        const data = await apiCall('/admin-api/login', 'POST', { email, password });
        adminToken = data.token;
        adminCollege = data.college_name;
        adminEmail = data.email;
        
        localStorage.setItem('adminToken', adminToken);
        localStorage.setItem('adminCollege', adminCollege);
        localStorage.setItem('adminEmail', adminEmail);
        
        showToast('Login successful', 'success');
        showApp();
    } catch (err) {}
});

// Logout Handler
logoutBtn.addEventListener('click', handleLogout);

async function handleLogout() {
    const tokenToRevoke = adminToken;
    
    // Clear local session state immediately to prevent any recursive call loops
    adminToken = '';
    adminCollege = '';
    adminEmail = '';
    localStorage.removeItem('adminToken');
    localStorage.removeItem('adminCollege');
    localStorage.removeItem('adminEmail');
    showLogin();
    
    // Notify the server asynchronously using raw fetch to prevent recursion
    if (tokenToRevoke) {
        try {
            await fetch(`${API_BASE}/admin-api/logout`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${tokenToRevoke}`
                }
            });
        } catch (err) {
            console.log('Logout notification failed:', err);
        }
    }
}

// Tab switcher logic
navItems.forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const tabId = item.getAttribute('data-tab');
        switchTab(tabId);
    });
});

function switchTab(tabId) {
    navItems.forEach(nav => {
        if (nav.getAttribute('data-tab') === tabId) {
            nav.classList.add('active');
        } else {
            nav.classList.remove('active');
        }
    });
    
    tabPanes.forEach(pane => {
        if (pane.id === tabId) {
            pane.classList.add('active');
        } else {
            pane.classList.remove('active');
        }
    });
    
    // Set titles and load tab-specific data
    if (tabId === 'stats-tab') {
        pageTitle.textContent = 'Dashboard Overview';
        loadStats();
    } else if (tabId === 'buildings-tab') {
        pageTitle.textContent = 'Manage Hostel & Academic Buildings';
        loadBuildings();
    } else if (tabId === 'restaurants-tab') {
        pageTitle.textContent = 'Manage Campus Restaurants';
        loadRestaurants();
    } else if (tabId === 'logs-tab') {
        pageTitle.textContent = 'Monthly Transaction Logs & Payouts';
        loadLogsTab();
    }
}

// Tab 1: Load Stats
async function loadStats() {
    try {
        const stats = await apiCall('/admin-api/stats');
        statUsers.textContent = stats.users;
        statRestaurants.textContent = stats.restaurants;
        statOrders.textContent = stats.completed_orders;
        statEarnings.textContent = `₹${stats.total_earnings}`;
    } catch (err) {}
}

// Tab 2: Buildings Operations
async function loadBuildings() {
    try {
        const data = await apiCall('/admin-api/buildings');
        currentBuildings = data.buildings || [];
        renderBuildings();
    } catch (err) {}
}

function renderBuildings() {
    buildingsList.innerHTML = '';
    buildingsCount.textContent = `${currentBuildings.length} building${currentBuildings.length === 1 ? '' : 's'}`;
    
    if (currentBuildings.length === 0) {
        buildingsList.innerHTML = `<div class="panel-body" style="grid-column: 1/-1; text-align: center; color: var(--color-text-sub);">No buildings configured. Add your first building above.</div>`;
        return;
    }
    
    currentBuildings.forEach((b, index) => {
        const card = document.createElement('div');
        card.className = 'building-card';
        card.innerHTML = `
            <div class="building-details">
                <h4>${b.name}</h4>
                <span class="gender-${b.gender}">${b.gender}</span>
            </div>
            <div class="building-actions">
                <button class="delete-b-btn" onclick="deleteBuilding(${index})">
                    <i class="fa-solid fa-trash"></i>
                </button>
            </div>
        `;
        buildingsList.appendChild(card);
    });
}

// Add Building Form
addBuildingForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = bName.value.trim();
    const gender = bGender.value;
    
    // Check if name already exists
    if (currentBuildings.some(b => b.name.toLowerCase() === name.toLowerCase())) {
        showToast('Building name already exists', 'error');
        return;
    }
    
    const updatedList = [...currentBuildings, { name, gender }];
    
    try {
        await apiCall('/admin-api/buildings', 'POST', { buildings: updatedList });
        showToast('Building added successfully', 'success');
        bName.value = '';
        bGender.value = 'Neutral';
        currentBuildings = updatedList;
        renderBuildings();
    } catch (err) {}
});

// Delete Building
async function deleteBuilding(index) {
    if (!confirm(`Are you sure you want to delete "${currentBuildings[index].name}"?`)) return;
    
    const updatedList = currentBuildings.filter((_, idx) => idx !== index);
    
    try {
        await apiCall('/admin-api/buildings', 'POST', { buildings: updatedList });
        showToast('Building deleted', 'success');
        currentBuildings = updatedList;
        renderBuildings();
    } catch (err) {}
}

// Tab 3: Restaurant Operations
async function loadRestaurants() {
    try {
        const data = await apiCall('/admin-api/restaurants');
        renderRestaurants(data.restaurants || []);
    } catch (err) {}
}

function renderRestaurants(restaurants) {
    restaurantsList.innerHTML = '';
    
    if (restaurants.length === 0) {
        restaurantsList.innerHTML = `<div class="panel-body" style="grid-column: 1/-1; text-align: center; color: var(--color-text-sub);">No restaurants registered for this college. Click "Register Restaurant" above.</div>`;
        return;
    }
    
    restaurants.forEach(r => {
        const card = document.createElement('div');
        card.className = 'restaurant-card';
        card.innerHTML = `
            <div>
                <div class="restaurant-info-header">
                    <h3>${r.name}</h3>
                    <span class="cuisine-badge">${r.cuisine_type}</span>
                </div>
                <p class="restaurant-desc">${r.description}</p>
                <div class="restaurant-details-list">
                    <div class="restaurant-detail-item">
                        <i class="fa-solid fa-envelope"></i> <span>${r.email}</span>
                    </div>
                    <div class="restaurant-detail-item">
                        <i class="fa-solid fa-phone"></i> <span>${r.phone}</span>
                    </div>
                    <div class="restaurant-detail-item">
                        <i class="fa-solid fa-map-location-dot"></i> <span>${r.address}</span>
                    </div>
                    <div class="restaurant-detail-item">
                        <i class="fa-solid fa-star" style="color: #f1c40f;"></i> <span>Rating: ${r.rating || '4.0'}</span>
                    </div>
                </div>
            </div>
            <div class="restaurant-actions">
                <label class="switch-container">
                    <input type="checkbox" ${r.is_open ? 'checked' : ''} onchange="toggleRestaurantStatus(${r.id}, this)">
                    <span class="switch-slider"></span>
                    <span class="switch-label">${r.is_open ? 'Open' : 'Closed'}</span>
                </label>
                <button class="btn btn-secondary" onclick="openEditRestaurantModal(${JSON.stringify(r).replace(/"/g, '&quot;')})">
                    <i class="fa-solid fa-pen-to-square"></i> Edit
                </button>
            </div>
        `;
        restaurantsList.appendChild(card);
    });
}

// Toggle Restaurant Status Switcher
async function toggleRestaurantStatus(id, checkbox) {
    const isChecked = checkbox.checked;
    const label = checkbox.nextElementSibling.nextElementSibling;
    label.textContent = isChecked ? 'Open' : 'Closed';
    
    try {
        // Fetch restaurant details to update status
        const restaurants = await apiCall('/admin-api/restaurants');
        const rest = restaurants.restaurants.find(r => r.id === id);
        
        if (rest) {
            await apiCall(`/admin-api/restaurants/${id}`, 'PUT', {
                name: rest.name,
                description: rest.description,
                cuisine_type: rest.cuisine_type,
                address: rest.address,
                phone: rest.phone,
                is_open: isChecked
            });
            showToast(`${rest.name} status updated`, 'success');
        }
    } catch (err) {
        // Revert switch on error
        checkbox.checked = !isChecked;
        label.textContent = !isChecked ? 'Open' : 'Closed';
    }
}

// Modal Handlers
addRestaurantBtn.addEventListener('click', () => {
    modalTitle.textContent = 'Register New Restaurant';
    editRestId.value = '';
    restaurantForm.reset();
    passwordGroup.style.display = 'block';
    restPassword.setAttribute('required', 'true');
    statusToggleGroup.style.display = 'none';
    restaurantModal.classList.add('active');
});

// Close modal handlers
document.querySelectorAll('.close-modal').forEach(btn => {
    btn.addEventListener('click', () => {
        restaurantModal.classList.remove('active');
    });
});

window.addEventListener('click', (e) => {
    if (e.target === restaurantModal) {
        restaurantModal.classList.remove('active');
    }
});

function openEditRestaurantModal(r) {
    modalTitle.textContent = `Edit Restaurant: ${r.name}`;
    editRestId.value = r.id;
    restName.value = r.name;
    restEmail.value = r.email;
    
    // Hide password group during editing to avoid rewriting it
    passwordGroup.style.display = 'none';
    restPassword.removeAttribute('required');
    restPassword.value = '';
    
    restDesc.value = r.description;
    restCuisine.value = r.cuisine_type;
    restPhone.value = r.phone;
    restAddress.value = r.address;
    
    statusToggleGroup.style.display = 'block';
    restIsOpen.checked = r.is_open;
    
    restaurantModal.classList.add('active');
}

// Submit Register/Edit Restaurant Form
restaurantForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = editRestId.value;
    const isEditing = id !== '';
    
    const payload = {
        name: restName.value.trim(),
        description: restDesc.value.trim(),
        cuisine_type: restCuisine.value.trim(),
        address: restAddress.value.trim(),
        phone: restPhone.value.trim(),
    };
    
    try {
        if (isEditing) {
            payload.is_open = restIsOpen.checked;
            await apiCall(`/admin-api/restaurants/${id}`, 'PUT', payload);
            showToast('Restaurant updated successfully', 'success');
        } else {
            payload.email = restEmail.value.trim();
            payload.password = restPassword.value;
            await apiCall('/admin-api/restaurants', 'POST', payload);
            showToast('Restaurant registered successfully', 'success');
        }
        
        restaurantModal.classList.remove('active');
        loadRestaurants();
    } catch (err) {}
});

// Tab 4: Logs and Payouts Operations
const logsMonthSelect = document.getElementById('logs-month-select');
const canteenPayoutsList = document.getElementById('canteen-payouts-list');
const deliveryPayoutsList = document.getElementById('delivery-payouts-list');
const canteenTotalPayout = document.getElementById('canteen-total-payout');
const deliveryTotalPayout = document.getElementById('delivery-total-payout');
const rawLogsList = document.getElementById('raw-logs-list');

logsMonthSelect.addEventListener('change', (e) => {
    loadMonthPayouts(e.target.value);
});

async function loadLogsTab() {
    try {
        const data = await apiCall('/admin-api/logs/months');
        logsMonthSelect.innerHTML = '';
        
        const months = data.months || [];
        if (months.length === 0) {
            const currentMonthStr = new Date().toISOString().substring(0, 7);
            const opt = document.createElement('option');
            opt.value = currentMonthStr;
            opt.textContent = currentMonthStr;
            logsMonthSelect.appendChild(opt);
            loadMonthPayouts(currentMonthStr);
            return;
        }
        
        months.forEach(m => {
            const opt = document.createElement('option');
            opt.value = m;
            opt.textContent = m;
            logsMonthSelect.appendChild(opt);
        });
        
        loadMonthPayouts(months[0]);
    } catch (err) {}
}

async function loadMonthPayouts(month) {
    try {
        const data = await apiCall(`/admin-api/logs/payouts?month=${month}`);
        
        // 1. Render Canteen Payouts
        canteenPayoutsList.innerHTML = '';
        let cTotal = 0.0;
        const canteens = data.canteen_payouts || [];
        if (canteens.length === 0) {
            canteenPayoutsList.innerHTML = `<tr><td colspan="4" style="text-align: center; color: var(--color-text-sub);">No transactions recorded.</td></tr>`;
        } else {
            canteens.forEach(c => {
                cTotal += c.restaurant_share;
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td><strong>${c.name}</strong></td>
                    <td>${c.transactions_count}</td>
                    <td>₹${c.gross_amount.toFixed(2)}</td>
                    <td style="color: var(--color-secondary); font-weight: 700;">₹${c.restaurant_share.toFixed(2)}</td>
                `;
                canteenPayoutsList.appendChild(tr);
            });
        }
        canteenTotalPayout.textContent = `Total: ₹${cTotal.toFixed(2)}`;

        // 2. Render Delivery Partner Payouts
        deliveryPayoutsList.innerHTML = '';
        let dTotal = 0.0;
        const deliverers = data.delivery_payouts || [];
        if (deliverers.length === 0) {
            deliveryPayoutsList.innerHTML = `<tr><td colspan="3" style="text-align: center; color: var(--color-text-sub);">No deliveries completed.</td></tr>`;
        } else {
            deliverers.forEach(d => {
                dTotal += d.delivery_share;
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td><strong>${d.name}</strong></td>
                    <td>${d.deliveries_count}</td>
                    <td style="color: var(--color-secondary); font-weight: 700;">₹${d.delivery_share.toFixed(2)}</td>
                `;
                deliveryPayoutsList.appendChild(tr);
            });
        }
        deliveryTotalPayout.textContent = `Total: ₹${dTotal.toFixed(2)}`;

        // 3. Render Downloadable CSV Files
        rawLogsList.innerHTML = '';
        const csvFiles = data.raw_csv_files || [];
        if (csvFiles.length === 0) {
            rawLogsList.innerHTML = `<div style="grid-column: 1/-1; text-align: center; color: var(--color-text-sub); padding: 16px;">No raw CSV log files exist for this month yet.</div>`;
        } else {
            csvFiles.forEach(f => {
                const sizeKb = (f.size_bytes / 1024).toFixed(1);
                const card = document.createElement('div');
                card.className = 'raw-log-card';
                card.innerHTML = `
                    <div class="raw-log-details">
                        <h4>${f.filename}</h4>
                        <p>${f.restaurant_name} (${sizeKb} KB)</p>
                    </div>
                    <button class="btn-download" onclick="downloadLogFile('${month}', ${f.restaurant_id}, '${f.restaurant_name}')">
                        <i class="fa-solid fa-download"></i>
                    </button>
                `;
                rawLogsList.appendChild(card);
            });
        }
    } catch (err) {}
}

async function downloadLogFile(month, restaurantId, canteenName) {
    try {
        const response = await fetch(`${API_BASE}/admin-api/logs/download?month=${month}&restaurant_id=${restaurantId}`, {
            headers: {
                'Authorization': `Bearer ${adminToken}`
            }
        });
        if (!response.ok) {
            throw new Error('Failed to download log file');
        }
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `transactions_${canteenName.replace(/\s+/g, '_')}_${month}.csv`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.URL.revokeObjectURL(url);
        showToast('File downloaded successfully', 'success');
    } catch (err) {
        showToast(err.message, 'error');
    }
}
