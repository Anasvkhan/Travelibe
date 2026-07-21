'use client';

import { useState, useEffect, useRef } from 'react';
import { io } from 'socket.io-client';
import { 
  Activity, 
  Hotel, 
  Plane, 
  ShieldAlert, 
  Plus, 
  MapPin, 
  CheckCircle,
  AlertTriangle,
  RefreshCw,
  ShoppingBag,
  LogOut,
  Lock,
  Edit,
  Trash,
  X,
  Search,
  Calendar
} from 'lucide-react';

let envUrl = process.env.NEXT_PUBLIC_API_URL;
if (envUrl && !envUrl.startsWith('http')) {
  envUrl = 'https://' + envUrl;
}
const API_BASE_URL = envUrl || 'http://localhost:9000';

const popularCountries = [
  "Bali, Indonesia",
  "Spain",
  "France",
  "United States",
  "Maldives",
  "Turkey",
  "Italy",
  "Pakistan",
  "United Kingdom",
  "Japan",
  "Thailand",
  "Switzerland",
  "Greece",
  "Egypt",
  "Saudi Arabia",
  "United Arab Emirates",
  "Singapore",
  "Malaysia"
];

export default function AdminDashboard() {
  const [token, setToken] = useState(null);
  const [email, setEmail] = useState('admin@travelibe.com');
  const [password, setPassword] = useState('password123');
  const [authError, setAuthError] = useState('');

  const [activeTab, setActiveTab] = useState('monitor');
  const [liveLogs, setLiveLogs] = useState([]);
  const [flightLogs, setFlightLogs] = useState([]);
  
  // Real database models
  const [properties, setProperties] = useState([]);
  const [products, setProducts] = useState([]);

  // Modals Visibility
  const [showPropertyModal, setShowPropertyModal] = useState(false);
  const [showProductModal, setShowProductModal] = useState(false);
  const [showCalendarModal, setShowCalendarModal] = useState(false);
  const [selectedUnit, setSelectedUnit] = useState(null);
  const [calendarForm, setCalendarForm] = useState({
    startDate: '',
    endDate: '',
    price: '100',
    availableCount: '5'
  });

  // SweetAlert custom popup state
  const [sweetAlert, setSweetAlert] = useState(null); // { title: '', text: '', type: 'success'|'error' }

  // Search country select dropdown state
  const [searchLocation, setSearchLocation] = useState('');
  const [showCountryDropdown, setShowCountryDropdown] = useState(false);

  // Editing items state
  const [editingPropertyId, setEditingPropertyId] = useState(null);
  const [editingProductId, setEditingProductId] = useState(null);

  // Consolidated Property & Unit Form State
  const [propertyForm, setPropertyForm] = useState({
    name: '',
    location: '',
    address: '',
    description: '',
    imageUrl: '',
    commissionRate: '0.05',
    roomName: 'Deluxe Balcony Suite',
    roomType: 'Deluxe',
    maxOccupancy: '2',
    basePricePerNight: '120',
    inventoryCount: '5'
  });

  // Shop Product Form State
  const [productForm, setProductForm] = useState({
    name: '',
    description: '',
    category: 'backpacks',
    imageUrl: '',
    variantName: 'Default Size',
    price: '49.99',
    sku: '',
    stockCount: '100'
  });

  // Flagged Moderation Items State
  const [flaggedItems, setFlaggedItems] = useState([
    { id: '1', reporter: 'Alice', type: 'POST', reason: 'Spam text content', details: 'Buy crypto now!', status: 'PENDING' },
    { id: '2', reporter: 'Bob', type: 'USER', reason: 'Harassment', details: '@bob reported bad DMs', status: 'PENDING' }
  ]);

  // Handle Admin Auth Login
  const handleLogin = async (e) => {
    e.preventDefault();
    setAuthError('');
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Login failed');
      }
      if (data.user.role !== 'SUPERADMIN') {
        throw new Error('Access denied: only SUPERADMIN role permitted');
      }
      setToken(data.token);
      localStorage.setItem('admin_token', data.token);
    } catch (err) {
      setAuthError(err.message);
    }
  };

  const handleLogout = () => {
    setToken(null);
    localStorage.removeItem('admin_token');
  };

  // Load properties, products, and launch WebSockets
  useEffect(() => {
    if (!token) return;

    loadProperties();
    loadProducts();

    const socket = io(API_BASE_URL, {
      query: { token },
      transports: ['websocket']
    });

    socket.on('connect', () => {
      addLog('Connected to Travelibe Real-time Monolith Engine.');
    });

    socket.on('presence_update', (data) => {
      addLog(`[Presence] User ${data.userId} went ${data.status}.`);
    });

    socket.on('new_message', (data) => {
      addLog(`[Chat] New message sent in conversation ${data.conversationId}.`);
    });

    socket.on('booking.reservation.confirmed', (data) => {
      addLog(`[Stays] Stay booking confirmed! Value: $${data.totalCost}, Platform 5% fee: $${data.commission}`);
      // Reload properties grid in background to reflect inventory change
      loadProperties();
    });

    return () => {
      socket.disconnect();
    };
  }, [token]);

  const loadProperties = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/stays/admin/properties`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setProperties(data);
      }
    } catch (err) {
      console.error('Failed to load properties', err);
    }
  };

  const loadProducts = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/shop/products`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setProducts(data);
      }
    } catch (err) {
      console.error('Failed to load products', err);
    }
  };

  const triggerSweetAlert = (title, text, type = 'success') => {
    setSweetAlert({ title, text, type });
    setTimeout(() => {
      setSweetAlert(null);
    }, 4000);
  };

  const addLog = (text) => {
    setLiveLogs((prev) => [{ time: new Date().toLocaleTimeString(), text }, ...prev.slice(0, 49)]);
  };

  const simulateFlightSearchLog = () => {
    const flightSearchSample = {
      time: new Date().toLocaleTimeString(),
      origin: 'ISB',
      destination: 'IST',
      date: '2026-09-18',
      status: 'API SUCCESS (Duffel)',
      latency: '340ms'
    };
    setFlightLogs((prev) => [flightSearchSample, ...prev]);
    addLog(`[Flights] Duffel API lookup request: ISB -> IST, Return: 2026-09-27.`);
  };

  // Handle File Upload from System
  const handleFileUpload = async (e, type) => {
    const file = e.target.files[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await fetch(`${API_BASE_URL}/api/upload/media`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`
        },
        body: formData
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Upload failed');

      if (type === 'property') {
        setPropertyForm(prev => ({ ...prev, imageUrl: data.mediaUrl }));
        triggerSweetAlert('Uploaded!', 'Property image uploaded successfully from system.', 'success');
      } else {
        setProductForm(prev => ({ ...prev, imageUrl: data.mediaUrl }));
        triggerSweetAlert('Uploaded!', 'Product image uploaded successfully from system.', 'success');
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // Handle Multiple Files Upload from System
  const handleFileUploadMultiple = async (e, type) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    const formData = new FormData();
    for (let i = 0; i < files.length; i++) {
      formData.append('files', files[i]);
    }

    try {
      const res = await fetch(`${API_BASE_URL}/api/upload/media-multiple`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`
        },
        body: formData
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Upload failed');

      const joinedUrls = data.mediaUrls.join(',');

      if (type === 'property') {
        setPropertyForm(prev => ({ ...prev, imageUrl: joinedUrls }));
        triggerSweetAlert('Uploaded!', `${data.mediaUrls.length} property photos uploaded successfully.`, 'success');
      } else {
        setProductForm(prev => ({ ...prev, imageUrl: joinedUrls }));
        triggerSweetAlert('Uploaded!', `${data.mediaUrls.length} product photos uploaded successfully.`, 'success');
      }
    } catch (err) {
      alert(err.message);
    }
  };

  // Open calendar overrides manager modal
  const handleManageCalendar = (prop) => {
    const unit = prop.units?.[0];
    if (!unit) {
      alert('This property does not have any room units configured.');
      return;
    }
    setSelectedUnit({
      id: unit.id,
      name: unit.name,
      propertyId: prop.id,
      propertyName: prop.name,
      basePrice: unit.basePricePerNight,
      defaultCount: unit.inventoryCount,
      inventoryDays: unit.inventoryDays || []
    });
    setCalendarForm({
      startDate: '',
      endDate: '',
      price: unit.basePricePerNight.toString(),
      availableCount: unit.inventoryCount.toString()
    });
    setShowCalendarModal(true);
  };

  // Submit date override calendar settings (Supports Range)
  const handleSaveCalendarOverride = async (e) => {
    e.preventDefault();
    if (!selectedUnit || !calendarForm.startDate || !calendarForm.endDate) return;

    try {
      const res = await fetch(`${API_BASE_URL}/api/stays/units/${selectedUnit.id}/calendar`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          startDate: calendarForm.startDate,
          endDate: calendarForm.endDate,
          availableCount: parseInt(calendarForm.availableCount, 10),
          price: parseFloat(calendarForm.price)
        })
      });

      if (!res.ok) throw new Error('Failed to save date range overrides');
      const data = await res.json(); // Array of upserted inventory days

      triggerSweetAlert('Calendar Updated!', `Saved overrides from ${calendarForm.startDate} to ${calendarForm.endDate}.`, 'success');
      addLog(`[Calendar] Set availability calendar overrides for unit ${selectedUnit.name} from ${calendarForm.startDate} to ${calendarForm.endDate}.`);
      
      // Reload properties grid to refresh overrides list
      await loadProperties();

      // Refresh local selected unit state to show updated override days
      setSelectedUnit(prev => {
        if (!prev) return null;
        const days = [...prev.inventoryDays];
        for (const newDay of data) {
          const idx = days.findIndex(d => d.date === newDay.date);
          if (idx > -1) {
            days[idx] = newDay;
          } else {
            days.push(newDay);
          }
        }
        return { ...prev, inventoryDays: days };
      });

      setCalendarForm(prev => ({ ...prev, startDate: '', endDate: '' }));
    } catch (err) {
      alert(err.message);
    }
  };

  // Submit property (Create or Update)
  const handleSaveProperty = async (e) => {
    e.preventDefault();
    if (!propertyForm.name || !propertyForm.location) return;

    try {
      const url = editingPropertyId 
        ? `${API_BASE_URL}/api/stays/properties/${editingPropertyId}`
        : `${API_BASE_URL}/api/stays/properties/consolidated`;
      
      const method = editingPropertyId ? 'PUT' : 'POST';

      const res = await fetch(url, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(propertyForm)
      });
      
      if (!res.ok) throw new Error('Failed to save property');
      
      const savedProperty = await res.json();

      setShowPropertyModal(false);
      setPropertyForm({
        name: '',
        location: '',
        address: '',
        description: '',
        imageUrl: '',
        commissionRate: '0.05',
        roomName: 'Deluxe Balcony Suite',
        roomType: 'Deluxe',
        maxOccupancy: '2',
        basePricePerNight: '120',
        inventoryCount: '5'
      });
      setSearchLocation('');
      setEditingPropertyId(null);
      
      triggerSweetAlert(
        editingPropertyId ? 'Property Updated!' : 'Property Posted!',
        `Successfully saved "${propertyForm.name}" in ${propertyForm.location}.`,
        'success'
      );
      addLog(`[Inventory] Saved property config "${propertyForm.name}" in ${propertyForm.location}.`);
      loadProperties();
    } catch (err) {
      triggerSweetAlert('Error saving property', err.message, 'error');
    }
  };

  const handleEditProperty = (prop) => {
    const unit = prop.units?.[0] || {};
    setEditingPropertyId(prop.id);
    setPropertyForm({
      name: prop.name || '',
      location: prop.location || '',
      address: prop.address || '',
      description: prop.description || '',
      imageUrl: prop.imageUrl || '',
      commissionRate: prop.commissionRate?.toString() || '0.05',
      roomName: unit.name || 'Standard Room',
      roomType: unit.roomType || 'Standard',
      maxOccupancy: unit.maxOccupancy?.toString() || '2',
      basePricePerNight: unit.basePricePerNight?.toString() || '100',
      inventoryCount: unit.inventoryCount?.toString() || '5'
    });
    setSearchLocation(prop.location || '');
    setShowPropertyModal(true);
  };

  const handleDeleteProperty = async (id) => {
    if (!confirm('Are you sure you want to delete this property inventory?')) return;
    try {
      const res = await fetch(`${API_BASE_URL}/api/stays/properties/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) throw new Error('Failed to delete property');
      triggerSweetAlert('Property Deleted!', 'The lodging record has been removed.', 'success');
      loadProperties();
    } catch (err) {
      triggerSweetAlert('Error deleting', err.message, 'error');
    }
  };

  // Submit product (Create or Update)
  const handleSaveProduct = async (e) => {
    e.preventDefault();
    if (!productForm.name || !productForm.sku) return;

    try {
      const url = editingProductId 
        ? `${API_BASE_URL}/api/shop/products/${editingProductId}`
        : `${API_BASE_URL}/api/shop/products`;
      
      const method = editingProductId ? 'PUT' : 'POST';

      const payload = {
        name: productForm.name,
        description: productForm.description,
        category: productForm.category,
        imageUrl: productForm.imageUrl || null,
        variants: [
          {
            name: productForm.variantName,
            price: parseFloat(productForm.price),
            sku: productForm.sku,
            stockCount: parseInt(productForm.stockCount, 10)
          }
        ]
      };

      const res = await fetch(url, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      
      if (!res.ok) throw new Error('Failed to save product');

      setShowProductModal(false);
      setEditingProductId(null);
      setProductForm({
        name: '',
        description: '',
        category: 'backpacks',
        imageUrl: '',
        variantName: 'Default Size',
        price: '49.99',
        sku: 'TB-PROD-' + Math.floor(Math.random()*10000),
        stockCount: '100'
      });

      triggerSweetAlert(
        editingProductId ? 'Product Updated!' : 'Product Posted!',
        `Successfully published "${productForm.name}" SKU: ${productForm.sku}.`,
        'success'
      );
      addLog(`[Shop] Saved product catalog config "${productForm.name}".`);
      loadProducts();
    } catch (err) {
      triggerSweetAlert('Error saving product', err.message, 'error');
    }
  };

  const handleEditProduct = (prod) => {
    const variant = prod.variants?.[0] || {};
    setEditingProductId(prod.id);
    setProductForm({
      name: prod.name || '',
      description: prod.description || '',
      category: prod.category || 'backpacks',
      imageUrl: prod.imageUrl || '',
      variantName: variant.name || 'Default Variant',
      price: variant.price?.toString() || '49.99',
      sku: variant.sku || '',
      stockCount: variant.stockCount?.toString() || '100'
    });
    setShowProductModal(true);
  };

  const handleDeleteProduct = async (id) => {
    if (!confirm('Are you sure you want to delete this product?')) return;
    try {
      const res = await fetch(`${API_BASE_URL}/api/shop/products/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) throw new Error('Failed to delete product');
      triggerSweetAlert('Product Deleted!', 'Catalog item has been removed.', 'success');
      loadProducts();
    } catch (err) {
      triggerSweetAlert('Error deleting', err.message, 'error');
    }
  };

  const handleResolveReport = (id, action) => {
    setFlaggedItems((prev) => prev.filter((item) => item.id !== id));
    addLog(`[Moderation] Resolved report case #${id} with action: ${action.toUpperCase()}`);
  };

  const filteredCountries = popularCountries.filter(c => 
    c.toLowerCase().includes(searchLocation.toLowerCase())
  );

  // 1. RENDER LOGIN SCREEN IF NOT AUTHENTICATED
  if (!token) {
    return (
      <div className="min-h-screen bg-slate-100 flex items-center justify-center p-6">
        <div className="bg-white p-8 rounded-xl shadow-lg border w-full max-w-md">
          <div className="flex flex-col items-center mb-6">
            <Lock className="text-emerald-700 w-12 h-12 mb-2" />
            <h1 className="text-2xl font-bold text-slate-800">Admin Control Login</h1>
            <p className="text-xs text-slate-500 mt-1">SUPERADMIN credentials required</p>
          </div>
          {authError && (
            <div className="bg-red-50 border border-red-200 text-red-700 text-sm p-3 rounded mb-4 text-center">
              {authError}
            </div>
          )}
          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-600 mb-1">Email Address</label>
              <input 
                type="email" 
                className="w-full border p-2.5 rounded focus:outline-none focus:ring-2 focus:ring-emerald-700" 
                value={email} 
                onChange={(e) => setEmail(e.target.value)} 
                required
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-600 mb-1">Password</label>
              <input 
                type="password" 
                className="w-full border p-2.5 rounded focus:outline-none focus:ring-2 focus:ring-emerald-700" 
                value={password} 
                onChange={(e) => setPassword(e.target.value)} 
                required
              />
            </div>
            <button 
              type="submit" 
              className="w-full bg-emerald-700 text-white py-2.5 rounded font-bold hover:bg-emerald-800 transition-colors mt-2"
            >
              Sign In
            </button>
          </form>
        </div>
      </div>
    );
  }

  // 2. RENDER MAIN CONTROL CENTER DASHBOARD
  return (
    <div className="flex h-screen bg-slate-50 text-slate-800 relative">
      
      {/* SWEET ALERT OVERLAY */}
      {sweetAlert && (
        <div className="fixed top-6 left-1/2 transform -translate-x-1/2 z-50 animate-bounce">
          <div className={`p-4 rounded-xl shadow-xl flex items-center space-x-3 border ${
            sweetAlert.type === 'error' ? 'bg-red-50 border-red-200 text-red-700' : 'bg-emerald-50 border-emerald-200 text-emerald-800'
          }`}>
            <CheckCircle className="w-6 h-6" />
            <div>
              <h4 className="font-bold text-sm">{sweetAlert.title}</h4>
              <p className="text-xs">{sweetAlert.text}</p>
            </div>
          </div>
        </div>
      )}

      {/* Sidebar Navigation */}
      <div className="w-64 bg-emerald-900 text-white flex flex-col p-6 space-y-8">
        <div>
          <h1 className="text-2xl font-bold tracking-wider">TRAVELIBE</h1>
          <p className="text-xs text-emerald-200">System Control Center</p>
        </div>

        <nav className="flex-1 flex flex-col space-y-3">
          <button 
            onClick={() => setActiveTab('monitor')} 
            className={`flex items-center space-x-3 p-3 rounded-lg transition-colors ${activeTab === 'monitor' ? 'bg-orange-500' : 'hover:bg-emerald-800'}`}
          >
            <Activity size={20} />
            <span>Live Monitor</span>
          </button>
          
          <button 
            onClick={() => setActiveTab('stays')} 
            className={`flex items-center space-x-3 p-3 rounded-lg transition-colors ${activeTab === 'stays' ? 'bg-orange-500' : 'hover:bg-emerald-800'}`}
          >
            <Hotel size={20} />
            <span>Direct Stays</span>
          </button>

          <button 
            onClick={() => setActiveTab('shop')} 
            className={`flex items-center space-x-3 p-3 rounded-lg transition-colors ${activeTab === 'shop' ? 'bg-orange-500' : 'hover:bg-emerald-800'}`}
          >
            <ShoppingBag size={20} />
            <span>Travelibe Shop</span>
          </button>

          <button 
            onClick={() => setActiveTab('flights')} 
            className={`flex items-center space-x-3 p-3 rounded-lg transition-colors ${activeTab === 'flights' ? 'bg-orange-500' : 'hover:bg-emerald-800'}`}
          >
            <Plane size={20} />
            <span>Flights API Log</span>
          </button>

          <button 
            onClick={() => setActiveTab('moderation')} 
            className={`flex items-center space-x-3 p-3 rounded-lg transition-colors ${activeTab === 'moderation' ? 'bg-orange-500' : 'hover:bg-emerald-800'}`}
          >
            <ShieldAlert size={20} />
            <span>Moderation Queue</span>
          </button>
        </nav>

        <div className="border-t border-emerald-800 pt-4 flex flex-col space-y-2">
          <button 
            onClick={handleLogout}
            className="flex items-center space-x-2 text-xs text-red-300 hover:text-red-100 transition-colors"
          >
            <LogOut size={16} />
            <span>Log Out Admin</span>
          </button>
          <div className="text-[10px] text-emerald-200">
            <p>Database: PostgreSQL</p>
            <p>Port: 9000 Sync</p>
          </div>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="bg-white border-b p-6 flex justify-between items-center shadow-sm">
          <h2 className="text-xl font-semibold capitalize">{activeTab} Dashboard</h2>
          <div className="flex items-center space-x-4">
            <span className="h-3 w-3 bg-green-500 rounded-full animate-pulse"></span>
            <span className="text-sm font-medium text-slate-600">WebSocket Sync: Active</span>
          </div>
        </header>

        {/* Tab Content Panels */}
        <main className="flex-1 overflow-auto p-8">
          
          {/* Tab 1: Live Monitor */}
          {activeTab === 'monitor' && (
            <div className="space-y-6">
              <div className="grid grid-cols-3 gap-6">
                <div className="bg-white p-6 rounded-lg shadow-sm border">
                  <h3 className="text-sm text-slate-500">Live Active Mobile Sockets</h3>
                  <p className="text-3xl font-bold text-emerald-800 mt-2">Active</p>
                </div>
                <div className="bg-white p-6 rounded-lg shadow-sm border">
                  <h3 className="text-sm text-slate-500">Platform Ledger Health</h3>
                  <p className="text-3xl font-bold text-emerald-800 mt-2">100% Balanced</p>
                </div>
                <div className="bg-white p-6 rounded-lg shadow-sm border">
                  <h3 className="text-sm text-slate-500">Ledger Errors</h3>
                  <p className="text-3xl font-bold text-green-600 mt-2">0 Cases</p>
                </div>
              </div>

              <div className="bg-white rounded-lg shadow-sm border p-6">
                <h3 className="text-lg font-semibold mb-4">Real-time Activity Logs</h3>
                <div className="bg-slate-900 text-green-400 font-mono text-sm p-4 rounded-lg h-96 overflow-y-auto space-y-2">
                  {liveLogs.length === 0 ? (
                    <div className="text-slate-500">Waiting for live WebSocket events... (Confirm bookings or send messages on mobile to test sync)</div>
                  ) : (
                    liveLogs.map((log, idx) => (
                      <div key={idx}>
                        <span className="text-slate-500">[{log.time}]</span> {log.text}
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Tab 2: Stays Inventory manager */}
          {activeTab === 'stays' && (
            <div className="space-y-6">
              <div className="flex justify-between items-center bg-white p-4 rounded-lg border shadow-sm">
                <div>
                  <h3 className="text-lg font-bold">Direct Stays Property Inventory</h3>
                  <p className="text-xs text-slate-500">Manage real properties and rates immediately visible in search results.</p>
                </div>
                <button 
                  onClick={() => {
                    setEditingPropertyId(null);
                    setPropertyForm({
                      name: '',
                      location: '',
                      address: '',
                      description: '',
                      commissionRate: '0.05',
                      roomName: 'Deluxe Balcony Suite',
                      roomType: 'Deluxe',
                      maxOccupancy: '2',
                      basePricePerNight: '120',
                      inventoryCount: '5'
                    });
                    setSearchLocation('');
                    setShowPropertyModal(true);
                  }}
                  className="bg-emerald-700 text-white px-4 py-2 rounded-lg flex items-center space-x-2 font-semibold hover:bg-emerald-800 transition-colors"
                >
                  <Plus size={18} />
                  <span>Post new property</span>
                </button>
              </div>

              {/* PROPERTIES GRID TABLE */}
              <div className="bg-white border rounded-xl shadow-sm overflow-hidden">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-50 border-b text-xs font-semibold text-slate-500 uppercase">
                      <th className="p-4">Property Name</th>
                      <th className="p-4">Location</th>
                      <th className="p-4">Address</th>
                      <th className="p-4">First Room Config</th>
                      <th className="p-4">Base Rate</th>
                      <th className="p-4">Inventory</th>
                      <th className="p-4 text-center">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y text-sm">
                    {properties.length === 0 ? (
                      <tr>
                        <td colSpan="7" className="p-8 text-center text-slate-400">No properties in database. Click "Post new property" to add.</td>
                      </tr>
                    ) : (
                      properties.map((prop) => {
                        const unit = prop.units?.[0] || {};
                        return (
                          <tr key={prop.id} className="hover:bg-slate-50">
                            <td className="p-4 font-semibold text-slate-800">{prop.name}</td>
                            <td className="p-4 text-emerald-800 font-bold">{prop.location}</td>
                            <td className="p-4 text-slate-500 max-w-xs truncate">{prop.address}</td>
                            <td className="p-4 text-slate-600 font-medium">{unit.name || 'N/A'}</td>
                            <td className="p-4 text-orange-500 font-bold">${unit.basePricePerNight || '100'}</td>
                            <td className="p-4 text-slate-600">{unit.inventoryCount || '0'} units</td>
                            <td className="p-4 text-center">
                              <div className="flex justify-center space-x-3">
                                <button 
                                  onClick={() => handleManageCalendar(prop)}
                                  className="text-slate-600 hover:text-emerald-700 transition-colors"
                                  title="Manage Availability & Price Calendar"
                                >
                                  <Calendar size={16} />
                                </button>
                                <button 
                                  onClick={() => handleEditProperty(prop)}
                                  className="text-slate-600 hover:text-blue-600 transition-colors"
                                >
                                  <Edit size={16} />
                                </button>
                                <button 
                                  onClick={() => handleDeleteProperty(prop.id)}
                                  className="text-slate-600 hover:text-red-600 transition-colors"
                                >
                                  <Trash size={16} />
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Tab 3: Travelibe Shop Products manager */}
          {activeTab === 'shop' && (
            <div className="space-y-6">
              <div className="flex justify-between items-center bg-white p-4 rounded-lg border shadow-sm">
                <div>
                  <h3 className="text-lg font-bold">Travelibe Gear Product Catalog</h3>
                  <p className="text-xs text-slate-500">Edit, add, or publish travel items directly queryable on the mobile app.</p>
                </div>
                <button 
                  onClick={() => {
                    setEditingProductId(null);
                    setProductForm({
                      name: '',
                      description: '',
                      category: 'backpacks',
                      variantName: 'Default Size',
                      price: '49.99',
                      sku: 'TB-PROD-' + Math.floor(Math.random()*10000),
                      stockCount: '100'
                    });
                    setShowProductModal(true);
                  }}
                  className="bg-emerald-700 text-white px-4 py-2 rounded-lg flex items-center space-x-2 font-semibold hover:bg-emerald-800 transition-colors"
                >
                  <Plus size={18} />
                  <span>Post new product</span>
                </button>
              </div>

              {/* PRODUCTS GRID TABLE */}
              <div className="bg-white border rounded-xl shadow-sm overflow-hidden">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-50 border-b text-xs font-semibold text-slate-500 uppercase">
                      <th className="p-4">Product Name</th>
                      <th className="p-4">Category</th>
                      <th className="p-4">Description</th>
                      <th className="p-4">Variant</th>
                      <th className="p-4">Price</th>
                      <th className="p-4">SKU</th>
                      <th className="p-4">Stock</th>
                      <th className="p-4 text-center">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y text-sm">
                    {products.length === 0 ? (
                      <tr>
                        <td colSpan="8" className="p-8 text-center text-slate-400">No products in catalog. Click "Post new product" to add.</td>
                      </tr>
                    ) : (
                      products.map((prod) => {
                        const variant = prod.variants?.[0] || {};
                        return (
                          <tr key={prod.id} className="hover:bg-slate-50">
                            <td className="p-4 font-semibold text-slate-800">{prod.name}</td>
                            <td className="p-4 text-emerald-800 font-bold">{prod.category}</td>
                            <td className="p-4 text-slate-500 max-w-xs truncate">{prod.description}</td>
                            <td className="p-4 text-slate-600">{variant.name || 'N/A'}</td>
                            <td className="p-4 text-orange-500 font-bold">${variant.price || '0.00'}</td>
                            <td className="p-4 text-slate-600 font-mono">{variant.sku || 'N/A'}</td>
                            <td className="p-4 text-slate-600">{variant.stockCount || '0'} left</td>
                            <td className="p-4 text-center">
                              <div className="flex justify-center space-x-3">
                                <button 
                                  onClick={() => handleEditProduct(prod)}
                                  className="text-slate-600 hover:text-blue-600 transition-colors"
                                >
                                  <Edit size={16} />
                                </button>
                                <button 
                                  onClick={() => handleDeleteProduct(prod.id)}
                                  className="text-slate-600 hover:text-red-600 transition-colors"
                                >
                                  <Trash size={16} />
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Tab 4: Flight log monitor */}
          {activeTab === 'flights' && (
            <div className="space-y-6">
              <div className="flex justify-between items-center">
                <p className="text-sm text-slate-600">Simulate search calls to test the Duffel logs monitor interface.</p>
                <button 
                  onClick={simulateFlightSearchLog}
                  className="bg-emerald-800 text-white px-4 py-2 rounded flex items-center gap-2 hover:bg-emerald-900 transition-colors"
                >
                  <RefreshCw size={16} />
                  Simulate search call
                </button>
              </div>

              <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-50 border-b text-sm font-semibold text-slate-600">
                      <th className="p-4">Timestamp</th>
                      <th className="p-4">Origin</th>
                      <th className="p-4">Destination</th>
                      <th className="p-4">Depart Date</th>
                      <th className="p-4">Duffel API Status</th>
                      <th className="p-4">API Latency</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y text-sm">
                    {flightLogs.length === 0 ? (
                      <tr>
                        <td colSpan="6" className="p-8 text-center text-slate-400">No Duffel search calls logged yet.</td>
                      </tr>
                    ) : (
                      flightLogs.map((log, idx) => (
                        <tr key={idx} className="hover:bg-slate-50">
                          <td className="p-4">{log.time}</td>
                          <td className="p-4 font-semibold">{log.origin}</td>
                          <td className="p-4 font-semibold">{log.destination}</td>
                          <td className="p-4">{log.date}</td>
                          <td className="p-4"><span className="bg-green-100 text-green-800 text-xs px-2 py-1 rounded font-bold">{log.status}</span></td>
                          <td className="p-4 text-slate-500">{log.latency}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Tab 5: Moderation Cases list */}
          {activeTab === 'moderation' && (
            <div className="bg-white rounded-lg border shadow-sm p-6">
              <h3 className="text-lg font-semibold mb-4">Pending Flagged Cases</h3>
              <div className="space-y-4">
                {flaggedItems.length === 0 ? (
                  <div className="text-center p-8 text-slate-400">Moderation queue is clean. Good job!</div>
                ) : (
                  flaggedItems.map((item) => (
                    <div key={item.id} className="border p-4 rounded-lg flex items-center justify-between hover:bg-slate-50">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <span className="bg-red-100 text-red-800 text-xs px-2 py-0.5 rounded font-bold">{item.type}</span>
                          <span className="text-xs text-slate-400">Reported by {item.reporter}</span>
                        </div>
                        <h4 className="font-semibold text-slate-700">{item.reason}</h4>
                        <p className="text-sm text-slate-500">"{item.details}"</p>
                      </div>
                      <div className="flex gap-2">
                        <button 
                          onClick={() => handleResolveReport(item.id, 'dismiss')}
                          className="border px-3 py-1.5 rounded text-sm hover:bg-slate-100 transition-colors"
                        >
                          Dismiss
                        </button>
                        <button 
                          onClick={() => handleResolveReport(item.id, 'suspend_user')}
                          className="bg-red-600 text-white px-3 py-1.5 rounded text-sm hover:bg-red-700 transition-colors"
                        >
                          Take Action
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}

        </main>
      </div>

      {/* CONSOLIDATED STAYS MODAL FORM */}
      {showPropertyModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-40 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-2xl overflow-hidden my-8">
            <div className="bg-slate-50 border-b p-6 flex justify-between items-center">
              <h3 className="text-lg font-bold text-slate-800">
                {editingPropertyId ? 'Edit Direct Property & Room' : 'Post New Property & Room Rate'}
              </h3>
              <button 
                onClick={() => setShowPropertyModal(false)}
                className="text-slate-500 hover:text-slate-700"
              >
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleSaveProperty} className="p-6 space-y-6 max-h-[80vh] overflow-y-auto">
              
              {/* SECTION 1: PROPERTY DETAILS */}
              <div>
                <h4 className="font-bold text-sm text-emerald-800 border-b pb-1 mb-4">1. Property Information</h4>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Property Name</label>
                    <input 
                      type="text"
                      className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700"
                      value={propertyForm.name}
                      onChange={(e) => setPropertyForm({ ...propertyForm, name: e.target.value })}
                      placeholder="e.g. Bali Beachfront Lodge"
                      required
                    />
                  </div>

                  {/* Searchable Country Select Dropdown */}
                  <div className="relative">
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Location City / Country</label>
                    <div className="flex border rounded overflow-hidden bg-white">
                      <input 
                        type="text"
                        className="w-full p-2 focus:outline-none"
                        value={searchLocation}
                        onChange={(e) => {
                          setSearchLocation(e.target.value);
                          setPropertyForm({ ...propertyForm, location: e.target.value });
                        }}
                        onFocus={() => setShowCountryDropdown(true)}
                        placeholder="Search & Select Location..."
                        required
                      />
                      <span className="p-2 text-slate-400"><Search size={16} /></span>
                    </div>

                    {showCountryDropdown && (
                      <div className="absolute left-0 right-0 mt-1 max-h-48 overflow-y-auto bg-white border rounded shadow-lg z-50">
                        {filteredCountries.length === 0 ? (
                          <div 
                            className="p-2 text-xs text-slate-400 cursor-pointer hover:bg-slate-100"
                            onClick={() => {
                              setPropertyForm({ ...propertyForm, location: searchLocation });
                              setShowCountryDropdown(false);
                            }}
                          >
                            Use custom: "{searchLocation}"
                          </div>
                        ) : (
                          filteredCountries.map((country) => (
                            <div 
                              key={country}
                              className="p-2 text-sm cursor-pointer hover:bg-slate-100 text-slate-700"
                              onClick={() => {
                                setSearchLocation(country);
                                setPropertyForm({ ...propertyForm, location: country });
                                setShowCountryDropdown(false);
                              }}
                            >
                              {country}
                            </div>
                          ))
                        )}
                      </div>
                    )}
                  </div>
                </div>

                <div className="mt-4">
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Full Address</label>
                  <input 
                    type="text"
                    className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700"
                    value={propertyForm.address}
                    onChange={(e) => setPropertyForm({ ...propertyForm, address: e.target.value })}
                    placeholder="e.g. Pantai Kuta Road No. 10, Bali"
                    required
                  />
                </div>

                <div className="mt-4">
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Description</label>
                  <textarea 
                    className="w-full border p-2 rounded h-20 focus:ring-1 focus:ring-emerald-700"
                    value={propertyForm.description}
                    onChange={(e) => setPropertyForm({ ...propertyForm, description: e.target.value })}
                    placeholder="Describe amenities, ocean view villa features..."
                    required
                  />
                </div>

                <div className="mt-4 grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Property Image URL (Comma-separated for multiple)</label>
                    <input 
                      type="text"
                      className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700"
                      value={propertyForm.imageUrl}
                      onChange={(e) => setPropertyForm({ ...propertyForm, imageUrl: e.target.value })}
                      placeholder="e.g. url1,url2,url3"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Or Upload Multiple Images</label>
                    <input 
                      type="file"
                      accept="image/*"
                      multiple
                      className="w-full border p-1.5 rounded bg-slate-50 text-xs cursor-pointer focus:ring-1 focus:ring-emerald-700"
                      onChange={(e) => handleFileUploadMultiple(e, 'property')}
                    />
                  </div>
                </div>
                {propertyForm.imageUrl && (
                  <div className="mt-2">
                    <p className="text-[10px] text-slate-500 mb-1">Uploaded Previews:</p>
                    <div className="flex gap-2 flex-wrap max-h-32 overflow-y-auto">
                      {propertyForm.imageUrl.split(',').filter(Boolean).map((url, index) => (
                        <img key={index} src={url} className="h-16 w-24 object-cover rounded border shadow-sm" alt={`Preview ${index + 1}`} />
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* SECTION 2: ROOM & RATE DETAILS */}
              <div>
                <h4 className="font-bold text-sm text-emerald-800 border-b pb-1 mb-4">2. Room Configuration</h4>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Room Name</label>
                    <input 
                      type="text"
                      className="w-full border p-2 rounded"
                      value={propertyForm.roomName}
                      onChange={(e) => setPropertyForm({ ...propertyForm, roomName: e.target.value })}
                      placeholder="e.g. Deluxe Balcony Suite"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Room Type</label>
                    <select
                      className="w-full border p-2 bg-white rounded"
                      value={propertyForm.roomType}
                      onChange={(e) => setPropertyForm({ ...propertyForm, roomType: e.target.value })}
                    >
                      <option value="Deluxe">Deluxe</option>
                      <option value="Standard">Standard</option>
                      <option value="Presidential">Presidential Suite</option>
                      <option value="Family">Family Villa</option>
                    </select>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-4 mt-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Max Guests Limit</label>
                    <input 
                      type="number"
                      className="w-full border p-2 rounded"
                      value={propertyForm.maxOccupancy}
                      onChange={(e) => setPropertyForm({ ...propertyForm, maxOccupancy: e.target.value })}
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Base Price / Night ($)</label>
                    <input 
                      type="number"
                      className="w-full border p-2 rounded"
                      value={propertyForm.basePricePerNight}
                      onChange={(e) => setPropertyForm({ ...propertyForm, basePricePerNight: e.target.value })}
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Inventory (Rooms count)</label>
                    <input 
                      type="number"
                      className="w-full border p-2 rounded"
                      value={propertyForm.inventoryCount}
                      onChange={(e) => setPropertyForm({ ...propertyForm, inventoryCount: e.target.value })}
                      required
                    />
                  </div>
                </div>
              </div>

              <button 
                type="submit"
                className="w-full bg-emerald-800 text-white py-3 rounded-xl font-bold hover:bg-emerald-900 transition-colors"
              >
                {editingPropertyId ? 'Save Changes' : 'Publish Property & Rates'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* SHOP PRODUCT MODAL FORM */}
      {showProductModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-40 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg overflow-hidden">
            <div className="bg-slate-50 border-b p-6 flex justify-between items-center">
              <h3 className="text-lg font-bold text-slate-800">
                {editingProductId ? 'Edit Shop Product' : 'Publish New Gear Product'}
              </h3>
              <button 
                onClick={() => setShowProductModal(false)}
                className="text-slate-500 hover:text-slate-700"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSaveProduct} className="p-6 space-y-6">
              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1">Product Name</label>
                <input 
                  type="text"
                  className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700"
                  value={productForm.name}
                  onChange={(e) => setProductForm({ ...productForm, name: e.target.value })}
                  placeholder="e.g. Travelibe Explorer Pack"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Category</label>
                  <select
                    className="w-full border p-2 bg-white rounded"
                    value={productForm.category}
                    onChange={(e) => setProductForm({ ...productForm, category: e.target.value })}
                  >
                    <option value="backpacks">Backpacks</option>
                    <option value="organizers">Organizers</option>
                    <option value="comfort">Comfort</option>
                    <option value="outdoor">Outdoor</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-600 mb-1">SKU Code (Must be unique)</label>
                  <input 
                    type="text"
                    className="w-full border p-2 rounded"
                    value={productForm.sku}
                    onChange={(e) => setProductForm({ ...productForm, sku: e.target.value })}
                    placeholder="e.g. TB-BAG-001"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1">Description</label>
                <textarea 
                  className="w-full border p-2 rounded h-20 focus:ring-1 focus:ring-emerald-700"
                  value={productForm.description}
                  onChange={(e) => setProductForm({ ...productForm, description: e.target.value })}
                  placeholder="Material specs, weight capacities..."
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Product Image URL (Comma-separated for multiple)</label>
                  <input 
                    type="text"
                    className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700"
                    value={productForm.imageUrl}
                    onChange={(e) => setProductForm({ ...productForm, imageUrl: e.target.value })}
                    placeholder="e.g. url1,url2,url3"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Or Upload Multiple Images</label>
                  <input 
                    type="file"
                    accept="image/*"
                    multiple
                    className="w-full border p-1.5 rounded bg-slate-50 text-xs cursor-pointer focus:ring-1 focus:ring-emerald-700"
                    onChange={(e) => handleFileUploadMultiple(e, 'product')}
                  />
                </div>
              </div>
              {productForm.imageUrl && (
                <div className="mt-2">
                  <p className="text-[10px] text-slate-500 mb-1">Uploaded Previews:</p>
                  <div className="flex gap-2 flex-wrap max-h-32 overflow-y-auto">
                    {productForm.imageUrl.split(',').filter(Boolean).map((url, index) => (
                      <img key={index} src={url} className="h-16 w-24 object-cover rounded border shadow-sm" alt={`Preview ${index + 1}`} />
                    ))}
                  </div>
                </div>
              )}

              <div className="border-t pt-4 grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Variant Name</label>
                  <input 
                    type="text"
                    className="w-full border p-2 rounded"
                    value={productForm.variantName}
                    onChange={(e) => setProductForm({ ...productForm, variantName: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Price ($)</label>
                  <input 
                    type="number"
                    step="0.01"
                    className="w-full border p-2 rounded"
                    value={productForm.price}
                    onChange={(e) => setProductForm({ ...productForm, price: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-600 mb-1">Stock count</label>
                  <input 
                    type="number"
                    className="w-full border p-2 rounded"
                    value={productForm.stockCount}
                    onChange={(e) => setProductForm({ ...productForm, stockCount: e.target.value })}
                    required
                  />
                </div>
              </div>

              <button 
                type="submit"
                className="w-full bg-emerald-800 text-white py-3 rounded-xl font-bold hover:bg-emerald-900 transition-colors"
              >
                {editingProductId ? 'Save Product Changes' : 'Publish Product Catalog'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* CALENDAR AVAILABILITY OVERRIDES MODAL */}
      {showCalendarModal && selectedUnit && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-40 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-2xl overflow-hidden my-8">
            <div className="bg-slate-50 border-b p-6 flex justify-between items-center">
              <div>
                <h3 className="text-lg font-bold text-slate-800">Manage Availability & Price Calendar</h3>
                <p className="text-xs text-slate-500">{selectedUnit.propertyName} - {selectedUnit.name}</p>
              </div>
              <button 
                onClick={() => setShowCalendarModal(false)}
                className="text-slate-500 hover:text-slate-700"
              >
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 grid grid-cols-2 gap-8">
              {/* Form to add override */}
              <div>
                <h4 className="font-bold text-sm text-emerald-800 mb-4">Add Date Override</h4>
                <form onSubmit={handleSaveCalendarOverride} className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-semibold text-slate-600 mb-1">Start Date</label>
                      <input 
                        type="date"
                        className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700 text-xs"
                        value={calendarForm.startDate}
                        onChange={(e) => setCalendarForm({ ...calendarForm, startDate: e.target.value })}
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-semibold text-slate-600 mb-1">End Date</label>
                      <input 
                        type="date"
                        className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700 text-xs"
                        value={calendarForm.endDate}
                        onChange={(e) => setCalendarForm({ ...calendarForm, endDate: e.target.value })}
                        required
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Price / Night ($)</label>
                    <input 
                      type="number"
                      className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700"
                      value={calendarForm.price}
                      onChange={(e) => setCalendarForm({ ...calendarForm, price: e.target.value })}
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Rooms Available (0 to block/close booking)</label>
                    <input 
                      type="number"
                      className="w-full border p-2 rounded focus:ring-1 focus:ring-emerald-700"
                      value={calendarForm.availableCount}
                      onChange={(e) => setCalendarForm({ ...calendarForm, availableCount: e.target.value })}
                      required
                    />
                  </div>
                  <button 
                    type="submit"
                    className="w-full bg-emerald-800 text-white py-2 rounded-lg font-bold hover:bg-emerald-900 transition-colors"
                  >
                    Save Override
                  </button>
                </form>
                
                <div className="mt-6 p-4 bg-emerald-50 rounded-lg text-xs text-emerald-800 border border-emerald-100">
                  <p><strong>Note:</strong> By default, rooms use the global settings (<strong>Price: ${selectedUnit.basePrice}</strong>, <strong>Count: {selectedUnit.defaultCount}</strong>). Selecting a date range lets you batch-update rates or block bookings (rooms count = 0) all at once.</p>
                </div>
              </div>

              {/* Overrides list */}
              <div className="flex flex-col h-full">
                <h4 className="font-bold text-sm text-emerald-800 mb-4">Active Date Overrides</h4>
                <div className="flex-1 overflow-y-auto max-h-80 border rounded-lg divide-y bg-slate-50">
                  {selectedUnit.inventoryDays.length === 0 ? (
                    <div className="p-8 text-center text-xs text-slate-400">No custom date overrides yet. Using global defaults.</div>
                  ) : (
                    selectedUnit.inventoryDays.map((day) => (
                      <div key={day.id} className="p-3 bg-white flex justify-between items-center text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{day.date}</p>
                          <p className="text-slate-500">Rooms: {day.availableCount === 0 ? <span className="text-red-600 font-bold">BLOCKED</span> : day.availableCount}</p>
                        </div>
                        <div className="text-right">
                          <p className="font-bold text-orange-600">${day.price}</p>
                          <p className="text-[10px] text-slate-400">Custom Rate</p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
