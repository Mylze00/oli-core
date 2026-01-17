export const getToken = () => localStorage.getItem('oli_admin_token');
export const setToken = (token) => localStorage.setItem('oli_admin_token', token);
export const removeToken = () => localStorage.removeItem('oli_admin_token');

export const getUser = () => {
    const userStr = localStorage.getItem('oli_admin_user');
    return userStr ? JSON.parse(userStr) : null;
};

export const setUser = (user) => {
    localStorage.setItem('oli_admin_user', JSON.stringify(user));
};

export const removeUser = () => localStorage.removeItem('oli_admin_user');

export const isAuthenticated = () => !!getToken();
