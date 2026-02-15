import { useEffect, useState } from 'react';
import {
    CircleStackIcon,
    TableCellsIcon,
    CommandLineIcon,
    ArrowPathIcon,
    ChevronLeftIcon,
    ChevronRightIcon,
    TrashIcon,
    MagnifyingGlassIcon,
    ExclamationTriangleIcon,
    CheckCircleIcon,
    XMarkIcon
} from '@heroicons/react/24/outline';
import api from '../services/api';

const TABS = [
    { id: 'overview', label: 'Vue d\'ensemble', icon: CircleStackIcon },
    { id: 'tables', label: 'Tables', icon: TableCellsIcon },
    { id: 'query', label: 'Requêtes SQL', icon: CommandLineIcon },
];

export default function DatabaseManager() {
    const [activeTab, setActiveTab] = useState('overview');
    const [stats, setStats] = useState(null);
    const [tables, setTables] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedTable, setSelectedTable] = useState(null);
    const [tableDetail, setTableDetail] = useState(null);
    const [tableData, setTableData] = useState(null);
    const [currentPage, setCurrentPage] = useState(1);
    const [sqlQuery, setSqlQuery] = useState('SELECT * FROM users LIMIT 10;');
    const [queryResult, setQueryResult] = useState(null);
    const [queryLoading, setQueryLoading] = useState(false);
    const [queryError, setQueryError] = useState(null);
    const [notification, setNotification] = useState(null);
    // Search & Filter
    const [searchTerm, setSearchTerm] = useState('');
    const [searchColumn, setSearchColumn] = useState('');
    const [tableColumns, setTableColumns] = useState([]);
    const [searchTimeout, setSearchTimeout] = useState(null);
    const [sortColumn, setSortColumn] = useState('id');
    const [sortOrder, setSortOrder] = useState('desc');

    useEffect(() => {
        fetchStats();
        fetchTables();
    }, []);

    const showNotification = (message, type = 'success') => {
        setNotification({ message, type });
        setTimeout(() => setNotification(null), 4000);
    };

    const fetchStats = async () => {
        try {
            const res = await api.get('/admin/database/stats');
            setStats(res.data);
        } catch (err) {
            console.error('Stats error:', err);
        }
    };

    const fetchTables = async () => {
        setLoading(true);
        try {
            const res = await api.get('/admin/database/tables');
            setTables(res.data);
        } catch (err) {
            console.error('Tables error:', err);
        } finally {
            setLoading(false);
        }
    };

    const fetchTableDetail = async (tableName) => {
        try {
            const res = await api.get(`/admin/database/tables/${tableName}`);
            setTableDetail(res.data);
        } catch (err) {
            console.error('Table detail error:', err);
        }
    };

    const fetchTableData = async (tableName, page = 1, search = searchTerm, column = searchColumn, sort = sortColumn, order = sortOrder) => {
        try {
            const params = new URLSearchParams({ page, limit: 25, sort, order });
            if (search.trim()) params.append('search', search.trim());
            if (column) params.append('searchColumn', column);
            const res = await api.get(`/admin/database/tables/${tableName}/data?${params}`);
            setTableData(res.data);
            setCurrentPage(page);
            if (res.data.columns) setTableColumns(res.data.columns);
        } catch (err) {
            console.error('Table data error:', err);
        }
    };

    const handleSearch = (value) => {
        setSearchTerm(value);
        if (searchTimeout) clearTimeout(searchTimeout);
        const timeout = setTimeout(() => {
            fetchTableData(selectedTable, 1, value, searchColumn);
        }, 400);
        setSearchTimeout(timeout);
    };

    const handleSearchColumnChange = (col) => {
        setSearchColumn(col);
        if (searchTerm.trim()) {
            fetchTableData(selectedTable, 1, searchTerm, col);
        }
    };

    const handleSort = (col) => {
        const newOrder = (sortColumn === col && sortOrder === 'desc') ? 'asc' : 'desc';
        setSortColumn(col);
        setSortOrder(newOrder);
        fetchTableData(selectedTable, 1, searchTerm, searchColumn, col, newOrder);
    };

    const clearSearch = () => {
        setSearchTerm('');
        setSearchColumn('');
        fetchTableData(selectedTable, 1, '', '');
    };

    const selectTable = (tableName) => {
        setSelectedTable(tableName);
        setSearchTerm('');
        setSearchColumn('');
        setSortColumn('id');
        setSortOrder('desc');
        fetchTableDetail(tableName);
        fetchTableData(tableName, 1, '', '', 'id', 'desc');
    };

    const executeQuery = async () => {
        setQueryLoading(true);
        setQueryError(null);
        setQueryResult(null);
        try {
            const res = await api.post('/admin/database/query', { sql: sqlQuery });
            setQueryResult(res.data);
        } catch (err) {
            setQueryError(err.response?.data?.error || err.message);
        } finally {
            setQueryLoading(false);
        }
    };

    const deleteRow = async (tableName, rowId) => {
        if (!confirm(`Supprimer la ligne #${rowId} de ${tableName} ?`)) return;
        try {
            await api.delete(`/admin/database/tables/${tableName}/rows/${rowId}`);
            showNotification(`Ligne #${rowId} supprimée`);
            fetchTableData(tableName, currentPage);
            fetchStats();
            fetchTables();
        } catch (err) {
            showNotification(err.response?.data?.error || 'Erreur', 'error');
        }
    };

    // ============================================================
    // RENDER: Overview Tab
    // ============================================================
    const renderOverview = () => {
        if (!stats) return <div className="text-center py-12 text-gray-500">Chargement...</div>;

        const cards = [
            { label: 'Taille de la DB', value: stats.database.size, color: 'from-blue-500 to-blue-600', icon: '💾' },
            { label: 'Tables', value: stats.database.tables, color: 'from-emerald-500 to-emerald-600', icon: '📋' },
            { label: 'Lignes totales', value: stats.database.total_rows.toLocaleString(), color: 'from-violet-500 to-violet-600', icon: '📊' },
            { label: 'Index', value: stats.database.indexes, color: 'from-amber-500 to-amber-600', icon: '🔍' },
            { label: 'Connexions actives', value: `${stats.connections.active} / ${stats.connections.max}`, color: 'from-rose-500 to-rose-600', icon: '🔌' },
            { label: 'Version', value: stats.database.version, color: 'from-cyan-500 to-cyan-600', icon: '🐘' },
        ];

        return (
            <div className="space-y-8">
                {/* KPI Cards */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                    {cards.map((card, i) => (
                        <div key={i} className={`bg-gradient-to-br ${card.color} rounded-2xl p-6 text-white shadow-lg hover:shadow-xl transition-shadow`}>
                            <div className="flex items-center justify-between">
                                <div>
                                    <p className="text-sm opacity-80 font-medium">{card.label}</p>
                                    <p className="text-2xl font-bold mt-1">{card.value}</p>
                                </div>
                                <span className="text-3xl">{card.icon}</span>
                            </div>
                        </div>
                    ))}
                </div>

                {/* Top Tables */}
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="p-6 border-b border-gray-100">
                        <h3 className="text-lg font-semibold text-gray-900">Top 5 Tables (par nombre de lignes)</h3>
                    </div>
                    <div className="overflow-x-auto">
                        <table className="w-full">
                            <thead className="bg-gray-50">
                                <tr>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Table</th>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Lignes</th>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Taille</th>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Action</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {stats.top_tables.map((t, i) => (
                                    <tr key={i} className="hover:bg-blue-50/50 transition-colors">
                                        <td className="px-6 py-4 font-medium text-gray-900">{t.table_name}</td>
                                        <td className="px-6 py-4 text-gray-600">{Number(t.row_count).toLocaleString()}</td>
                                        <td className="px-6 py-4 text-gray-600">{t.total_size}</td>
                                        <td className="px-6 py-4">
                                            <button
                                                onClick={() => { selectTable(t.table_name); setActiveTab('tables'); }}
                                                className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                                            >
                                                Explorer →
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        );
    };

    // ============================================================
    // RENDER: Tables Tab
    // ============================================================
    const renderTables = () => {
        if (!selectedTable) {
            // Table List
            return (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="p-6 border-b border-gray-100 flex items-center justify-between">
                        <h3 className="text-lg font-semibold text-gray-900">Toutes les Tables ({tables.length})</h3>
                        <button onClick={() => { fetchTables(); fetchStats(); }} className="flex items-center gap-2 text-sm text-blue-600 hover:text-blue-800">
                            <ArrowPathIcon className="h-4 w-4" /> Rafraîchir
                        </button>
                    </div>
                    <div className="overflow-x-auto">
                        <table className="w-full">
                            <thead className="bg-gray-50">
                                <tr>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Table</th>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Lignes</th>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Colonnes</th>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Taille</th>
                                    <th className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Action</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {tables.map((t, i) => (
                                    <tr key={i} className="hover:bg-blue-50/50 transition-colors cursor-pointer" onClick={() => selectTable(t.table_name)}>
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-2">
                                                <TableCellsIcon className="h-5 w-5 text-blue-500" />
                                                <span className="font-medium text-gray-900">{t.table_name}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                                {Number(t.row_count).toLocaleString()}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-gray-600">{t.column_count}</td>
                                        <td className="px-6 py-4 text-gray-600">{t.total_size}</td>
                                        <td className="px-6 py-4">
                                            <button className="text-blue-600 hover:text-blue-800 text-sm font-medium">
                                                Explorer →
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            );
        }

        // Table Detail View
        return (
            <div className="space-y-6">
                {/* Header */}
                <div className="flex items-center gap-4">
                    <button
                        onClick={() => { setSelectedTable(null); setTableDetail(null); setTableData(null); setSearchTerm(''); setSearchColumn(''); setTableColumns([]); setSortColumn('id'); setSortOrder('desc'); }}
                        className="flex items-center gap-1 text-gray-500 hover:text-gray-700"
                    >
                        <ChevronLeftIcon className="h-5 w-5" /> Retour
                    </button>
                    <div>
                        <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                            <TableCellsIcon className="h-6 w-6 text-blue-500" />
                            {selectedTable}
                        </h3>
                        <p className="text-sm text-gray-500">{tableDetail?.row_count || 0} lignes • {tableDetail?.columns?.length || 0} colonnes</p>
                    </div>
                </div>

                {/* Schema */}
                {tableDetail && (
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                        <div className="p-5 border-b border-gray-100 bg-gray-50">
                            <h4 className="font-semibold text-gray-700">Structure de la table</h4>
                        </div>
                        <div className="overflow-x-auto">
                            <table className="w-full text-sm">
                                <thead className="bg-gray-50">
                                    <tr>
                                        <th className="px-4 py-2 text-left text-xs font-semibold text-gray-500">Colonne</th>
                                        <th className="px-4 py-2 text-left text-xs font-semibold text-gray-500">Type</th>
                                        <th className="px-4 py-2 text-left text-xs font-semibold text-gray-500">Nullable</th>
                                        <th className="px-4 py-2 text-left text-xs font-semibold text-gray-500">Défaut</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-100">
                                    {tableDetail.columns.map((col, i) => (
                                        <tr key={i} className="hover:bg-gray-50">
                                            <td className="px-4 py-2 font-mono text-blue-700 font-medium">{col.column_name}</td>
                                            <td className="px-4 py-2 text-gray-600 font-mono text-xs">
                                                {col.data_type}{col.character_maximum_length ? `(${col.character_maximum_length})` : ''}
                                            </td>
                                            <td className="px-4 py-2">
                                                <span className={`text-xs px-2 py-0.5 rounded-full ${col.is_nullable === 'YES' ? 'bg-yellow-100 text-yellow-700' : 'bg-green-100 text-green-700'}`}>
                                                    {col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'}
                                                </span>
                                            </td>
                                            <td className="px-4 py-2 text-gray-500 text-xs font-mono">{col.column_default || '—'}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                )}

                {/* Data */}
                {tableData && (
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                        <div className="p-5 border-b border-gray-100 bg-gray-50">
                            <div className="flex items-center justify-between mb-4">
                                <h4 className="font-semibold text-gray-700">
                                    Données ({tableData.pagination.total} ligne{tableData.pagination.total > 1 ? 's' : ''})
                                    {searchTerm && <span className="text-sm font-normal text-blue-600 ml-2">— filtrées</span>}
                                </h4>
                                <button onClick={() => fetchTableData(selectedTable, currentPage)} className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
                                    <ArrowPathIcon className="h-4 w-4" /> Rafraîchir
                                </button>
                            </div>
                            {/* Search Bar */}
                            <div className="flex flex-col sm:flex-row gap-3">
                                <div className="relative flex-1">
                                    <MagnifyingGlassIcon className="h-4 w-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                                    <input
                                        type="text"
                                        value={searchTerm}
                                        onChange={(e) => handleSearch(e.target.value)}
                                        placeholder={searchColumn ? `Rechercher dans ${searchColumn}...` : 'Rechercher dans toutes les colonnes...'}
                                        className="w-full pl-9 pr-9 py-2.5 text-sm border border-gray-200 rounded-xl bg-white focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                                    />
                                    {searchTerm && (
                                        <button onClick={clearSearch} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                                            <XMarkIcon className="h-4 w-4" />
                                        </button>
                                    )}
                                </div>
                                <select
                                    value={searchColumn}
                                    onChange={(e) => handleSearchColumnChange(e.target.value)}
                                    className="px-3 py-2.5 text-sm border border-gray-200 rounded-xl bg-white focus:ring-2 focus:ring-blue-500 outline-none min-w-[180px]"
                                >
                                    <option value="">Toutes les colonnes</option>
                                    {tableColumns.map((col) => (
                                        <option key={col} value={col}>{col}</option>
                                    ))}
                                </select>
                            </div>
                        </div>
                        <div className="overflow-x-auto">
                            <table className="w-full text-sm">
                                <thead className="bg-gray-50">
                                    <tr>
                                        {(tableColumns.length > 0 ? tableColumns : (tableData.data.length > 0 ? Object.keys(tableData.data[0]) : [])).map((key) => (
                                            <th
                                                key={key}
                                                onClick={() => handleSort(key)}
                                                className="px-3 py-2 text-left text-xs font-semibold text-gray-500 whitespace-nowrap cursor-pointer hover:text-blue-600 hover:bg-blue-50/50 transition-colors select-none"
                                            >
                                                <span className="flex items-center gap-1">
                                                    {key}
                                                    {sortColumn === key && (
                                                        <span className="text-blue-600">{sortOrder === 'asc' ? '↑' : '↓'}</span>
                                                    )}
                                                </span>
                                            </th>
                                        ))}
                                        <th className="px-3 py-2 text-xs font-semibold text-gray-500">Actions</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-100">
                                    {tableData.data.map((row, i) => (
                                        <tr key={i} className="hover:bg-gray-50">
                                            {Object.values(row).map((val, j) => (
                                                <td key={j} className="px-3 py-2 text-gray-700 max-w-[200px] truncate whitespace-nowrap" title={String(val)}>
                                                    {val === null ? <span className="text-gray-300 italic">NULL</span> :
                                                        typeof val === 'object' ? JSON.stringify(val).substring(0, 50) :
                                                            String(val).substring(0, 80)}
                                                </td>
                                            ))}
                                            <td className="px-3 py-2">
                                                {row.id && (
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); deleteRow(selectedTable, row.id); }}
                                                        className="text-red-400 hover:text-red-600 p-1"
                                                        title="Supprimer"
                                                    >
                                                        <TrashIcon className="h-4 w-4" />
                                                    </button>
                                                )}
                                            </td>
                                        </tr>
                                    ))}
                                    {tableData.data.length === 0 && (
                                        <tr><td colSpan="100" className="px-6 py-8 text-center text-gray-400">Aucune donnée</td></tr>
                                    )}
                                </tbody>
                            </table>
                        </div>

                        {/* Pagination */}
                        {tableData.pagination.total_pages > 1 && (
                            <div className="px-6 py-4 border-t border-gray-100 flex items-center justify-between">
                                <p className="text-sm text-gray-500">
                                    Page {tableData.pagination.page} sur {tableData.pagination.total_pages}
                                </p>
                                <div className="flex gap-2">
                                    <button
                                        disabled={currentPage <= 1}
                                        onClick={() => fetchTableData(selectedTable, currentPage - 1)}
                                        className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-40"
                                    >
                                        <ChevronLeftIcon className="h-4 w-4" />
                                    </button>
                                    <button
                                        disabled={currentPage >= tableData.pagination.total_pages}
                                        onClick={() => fetchTableData(selectedTable, currentPage + 1)}
                                        className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-40"
                                    >
                                        <ChevronRightIcon className="h-4 w-4" />
                                    </button>
                                </div>
                            </div>
                        )}
                    </div>
                )}

                {/* Indexes */}
                {tableDetail?.indexes?.length > 0 && (
                    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                        <div className="p-5 border-b border-gray-100 bg-gray-50">
                            <h4 className="font-semibold text-gray-700">Index ({tableDetail.indexes.length})</h4>
                        </div>
                        <div className="p-4 space-y-2">
                            {tableDetail.indexes.map((idx, i) => (
                                <div key={i} className="bg-gray-50 rounded-lg p-3">
                                    <p className="font-mono text-sm text-blue-700 font-medium">{idx.indexname}</p>
                                    <p className="font-mono text-xs text-gray-500 mt-1">{idx.indexdef}</p>
                                </div>
                            ))}
                        </div>
                    </div>
                )}
            </div>
        );
    };

    // ============================================================
    // RENDER: Query Tab
    // ============================================================
    const renderQuery = () => (
        <div className="space-y-6">
            {/* SQL Editor */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-5 border-b border-gray-100 bg-gray-50 flex items-center justify-between">
                    <h4 className="font-semibold text-gray-700 flex items-center gap-2">
                        <CommandLineIcon className="h-5 w-5 text-violet-500" />
                        Éditeur SQL
                    </h4>
                    <div className="flex items-center gap-2">
                        <span className="text-xs text-amber-600 bg-amber-50 px-2 py-1 rounded-full">SELECT uniquement</span>
                    </div>
                </div>
                <div className="p-4">
                    <textarea
                        value={sqlQuery}
                        onChange={(e) => setSqlQuery(e.target.value)}
                        rows={6}
                        className="w-full font-mono text-sm bg-slate-900 text-green-400 rounded-xl p-4 border-0 focus:ring-2 focus:ring-blue-500 resize-y"
                        placeholder="SELECT * FROM users LIMIT 10;"
                        onKeyDown={(e) => {
                            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                                executeQuery();
                            }
                        }}
                    />
                    <div className="flex items-center justify-between mt-3">
                        <p className="text-xs text-gray-400">Raccourci : Ctrl + Entrée pour exécuter</p>
                        <button
                            onClick={executeQuery}
                            disabled={queryLoading}
                            className="px-6 py-2.5 bg-gradient-to-r from-violet-600 to-blue-600 text-white rounded-xl text-sm font-medium hover:from-violet-700 hover:to-blue-700 transition-all disabled:opacity-50 shadow-md hover:shadow-lg"
                        >
                            {queryLoading ? 'Exécution...' : '▶ Exécuter'}
                        </button>
                    </div>
                </div>
            </div>

            {/* Helper Queries */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                <h4 className="font-semibold text-gray-700 mb-3">Requêtes rapides</h4>
                <div className="flex flex-wrap gap-2">
                    {[
                        { label: 'Tous les utilisateurs', sql: 'SELECT id, phone, name, is_admin, is_seller, created_at FROM users ORDER BY id DESC LIMIT 50;' },
                        { label: 'Produits récents', sql: 'SELECT id, name, price, category, status, created_at FROM products ORDER BY created_at DESC LIMIT 50;' },
                        { label: 'Commandes payées', sql: "SELECT o.id, o.total_amount, o.status, o.payment_status, u.name AS buyer FROM orders o LEFT JOIN users u ON o.user_id = u.id WHERE o.payment_status = 'completed' ORDER BY o.created_at DESC;" },
                        { label: 'Boutiques', sql: 'SELECT s.id, s.name, s.category, s.total_products, u.name AS owner FROM shops s LEFT JOIN users u ON s.owner_id = u.id ORDER BY s.total_products DESC;' },
                        { label: 'Tailles des tables', sql: "SELECT relname AS table_name, n_live_tup AS rows, pg_size_pretty(pg_total_relation_size(relid)) AS size FROM pg_stat_user_tables ORDER BY n_live_tup DESC;" },
                    ].map((q, i) => (
                        <button
                            key={i}
                            onClick={() => { setSqlQuery(q.sql); }}
                            className="px-3 py-1.5 bg-gray-100 hover:bg-blue-100 text-gray-700 hover:text-blue-700 rounded-lg text-xs font-medium transition-colors"
                        >
                            {q.label}
                        </button>
                    ))}
                </div>
            </div>

            {/* Query Error */}
            {queryError && (
                <div className="bg-red-50 border border-red-200 rounded-2xl p-4 flex items-start gap-3">
                    <ExclamationTriangleIcon className="h-5 w-5 text-red-500 flex-shrink-0 mt-0.5" />
                    <div>
                        <p className="font-medium text-red-700">Erreur SQL</p>
                        <p className="text-sm text-red-600 font-mono mt-1">{queryError}</p>
                    </div>
                </div>
            )}

            {/* Query Result */}
            {queryResult && (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="p-5 border-b border-gray-100 bg-gray-50 flex items-center justify-between">
                        <h4 className="font-semibold text-gray-700">
                            Résultats ({queryResult.row_count} ligne{queryResult.row_count > 1 ? 's' : ''})
                        </h4>
                        <span className="text-xs text-gray-400">{queryResult.duration_ms}ms</span>
                    </div>
                    <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
                        <table className="w-full text-sm">
                            <thead className="bg-gray-50 sticky top-0">
                                <tr>
                                    {queryResult.fields.map((f, i) => (
                                        <th key={i} className="px-4 py-2 text-left text-xs font-semibold text-gray-500 whitespace-nowrap">{f.name}</th>
                                    ))}
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {queryResult.rows.map((row, i) => (
                                    <tr key={i} className="hover:bg-gray-50">
                                        {Object.values(row).map((val, j) => (
                                            <td key={j} className="px-4 py-2 text-gray-700 max-w-[250px] truncate whitespace-nowrap" title={String(val)}>
                                                {val === null ? <span className="text-gray-300 italic">NULL</span> :
                                                    typeof val === 'object' ? JSON.stringify(val) :
                                                        String(val)}
                                            </td>
                                        ))}
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}
        </div>
    );

    // ============================================================
    // MAIN RENDER
    // ============================================================
    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            {/* Notification Toast */}
            {notification && (
                <div className={`fixed top-6 right-6 z-50 flex items-center gap-3 px-5 py-3 rounded-xl shadow-lg text-white text-sm font-medium animate-slide-in ${notification.type === 'error' ? 'bg-red-500' : 'bg-green-500'
                    }`}>
                    {notification.type === 'error' ? <ExclamationTriangleIcon className="h-5 w-5" /> : <CheckCircleIcon className="h-5 w-5" />}
                    {notification.message}
                    <button onClick={() => setNotification(null)}><XMarkIcon className="h-4 w-4 opacity-70" /></button>
                </div>
            )}

            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-3">
                        <CircleStackIcon className="h-8 w-8 text-blue-600" />
                        Gestion de la Base de Données
                    </h1>
                    <p className="text-sm text-gray-500 mt-1">Explorer, monitorer et gérer la base PostgreSQL</p>
                </div>
                <button
                    onClick={() => { fetchStats(); fetchTables(); }}
                    className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition-colors"
                >
                    <ArrowPathIcon className="h-4 w-4" /> Rafraîchir tout
                </button>
            </div>

            {/* Tabs */}
            <div className="flex gap-1 bg-white rounded-xl p-1 shadow-sm mb-8 border border-gray-100 w-fit">
                {TABS.map((tab) => (
                    <button
                        key={tab.id}
                        onClick={() => { setActiveTab(tab.id); if (tab.id === 'tables') { setSelectedTable(null); setTableDetail(null); setTableData(null); } }}
                        className={`flex items-center gap-2 px-5 py-2.5 rounded-lg text-sm font-medium transition-all ${activeTab === tab.id
                            ? 'bg-blue-600 text-white shadow-md'
                            : 'text-gray-600 hover:bg-gray-100'
                            }`}
                    >
                        <tab.icon className="h-4 w-4" />
                        {tab.label}
                    </button>
                ))}
            </div>

            {/* Tab Content */}
            {activeTab === 'overview' && renderOverview()}
            {activeTab === 'tables' && renderTables()}
            {activeTab === 'query' && renderQuery()}
        </div>
    );
}
