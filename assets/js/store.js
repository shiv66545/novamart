const NovaStore = (() => {
  const seedProducts = [
    { id: 1, name: 'Nova Wireless Headphones', category: 'Electronics', price: 2499, rating: 4.8, icon: '🎧', stock: 24, description: 'Comfortable wireless headphones with rich sound and all-day battery life.' },
    { id: 2, name: 'Smart Watch Pro', category: 'Electronics', price: 3299, rating: 4.7, icon: '⌚', stock: 18, description: 'A modern smartwatch for notifications, activity tracking and everyday use.' },
    { id: 3, name: 'Everyday Sneakers', category: 'Fashion', price: 1899, rating: 4.6, icon: '👟', stock: 31, description: 'Lightweight everyday sneakers designed for comfortable casual wear.' },
    { id: 4, name: 'Minimal Backpack', category: 'Fashion', price: 1299, rating: 4.5, icon: '🎒', stock: 16, description: 'Clean, practical backpack with room for your daily essentials.' },
    { id: 5, name: 'Portable Speaker', category: 'Electronics', price: 1599, rating: 4.7, icon: '🔊', stock: 12, description: 'Compact portable speaker with clear audio for rooms and travel.' },
    { id: 6, name: 'Desk Lamp', category: 'Home', price: 899, rating: 4.4, icon: '💡', stock: 40, description: 'Minimal desk lamp for focused study and work sessions.' },
    { id: 7, name: 'Coffee Maker', category: 'Home', price: 2199, rating: 4.6, icon: '☕', stock: 9, description: 'Simple coffee maker for quick, convenient home brewing.' },
    { id: 8, name: 'Fitness Bottle', category: 'Sports', price: 699, rating: 4.3, icon: '🥤', stock: 55, description: 'Reusable bottle made for school, workouts and everyday hydration.' }
  ];
  const read = (key, fallback) => { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } };
  const write = (key, value) => localStorage.setItem(key, JSON.stringify(value));
  const getProducts = () => read('novamart-products', seedProducts);
  const saveProducts = products => { write('novamart-products', products); window.dispatchEvent(new Event('novamart-inventory-updated')); };
  const getCart = () => read('novamart-cart', []);
  const saveCart = cart => write('novamart-cart', cart);
  const getWishlist = () => read('novamart-wishlist', []);
  const saveWishlist = list => write('novamart-wishlist', list);
  const getOrders = () => read('novamart-orders', []);
  const money = value => `₹${Number(value).toLocaleString('en-IN')}`;
  const getProduct = id => getProducts().find(p => p.id === Number(id));
  const cartCount = () => getCart().reduce((sum, item) => sum + item.qty, 0);
  const cartTotal = () => getCart().reduce((sum, item) => { const p=getProduct(item.id); return sum + (p ? p.price * item.qty : 0); }, 0);
  const addToCart = (id, qty = 1) => {
    const p = getProduct(id); if (!p || p.stock <= 0) return false;
    const cart = getCart(); const item = cart.find(x => x.id === p.id); const current = item?.qty || 0;
    if (current + qty > p.stock) return false;
    if (item) item.qty += qty; else cart.push({ id: p.id, name: p.name, price: p.price, icon: p.icon, qty });
    saveCart(cart); return true;
  };
  const updateQty = (id, qty) => {
    const p=getProduct(id); const safe=Math.min(Math.max(0, qty), p?.stock ?? 0);
    const cart = getCart().map(x => x.id === Number(id) ? { ...x, qty: safe } : x).filter(x => x.qty > 0); saveCart(cart);
  };
  const removeFromCart = id => updateQty(id, 0);
  const toggleWishlist = id => { const list=getWishlist(); const n=Number(id); const i=list.indexOf(n); if(i>=0) list.splice(i,1); else list.push(n); saveWishlist(list); return !list.includes(n); };
  const isWishlisted = id => getWishlist().includes(Number(id));
  const placeOrder = customer => {
    const cart=getCart(); if(!cart.length) return null;
    for(const item of cart){const p=getProduct(item.id); if(!p || item.qty>p.stock) return null;}
    const products=getProducts(); cart.forEach(item=>{const p=products.find(x=>x.id===item.id); p.stock-=item.qty;}); saveProducts(products);
    const order={id:`NM-${Date.now().toString().slice(-8)}`,date:new Date().toISOString(),status:'Confirmed',customer,items:cart,total:cartTotal()};
    const orders=getOrders(); orders.unshift(order); write('novamart-orders',orders); saveCart([]); return order;
  };
  return { products: getProducts(), getProducts, saveProducts, getProduct, getCart, saveCart, getWishlist, saveWishlist, getOrders, money, cartCount, cartTotal, addToCart, updateQty, removeFromCart, toggleWishlist, isWishlisted, placeOrder, write, read };
})();