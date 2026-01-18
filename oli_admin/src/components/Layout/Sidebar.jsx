import { Link, useLocation } from 'react-router-dom';
import {
    HomeIcon,
    UsersIcon,
    ShoppingBagIcon,
    CubeIcon,
    CreditCardIcon,
    ExclamationTriangleIcon,
    TruckIcon,
    ShieldCheckIcon
} from '@heroicons/react/24/outline';

const navigation = [
    { name: 'Tableau de bord', href: '/', icon: HomeIcon },
    { name: 'Utilisateurs', href: '/users', icon: UsersIcon },
    { name: 'Marchands', href: '/shops', icon: ShoppingBagIcon },
    { name: 'Produits', href: '/products', icon: CubeIcon },
    { name: 'Livreurs', href: '/delivery', icon: TruckIcon },
    { name: 'Commandes', href: '/orders', icon: CubeIcon },
    { name: 'Finances', href: '/finances', icon: CreditCardIcon },
    { name: 'Modération', href: '/disputes', icon: ShieldCheckIcon },
];

function classNames(...classes) {
    return classes.filter(Boolean).join(' ')
}

export default function Sidebar() {
    const location = useLocation();

    return (
        <div className="flex flex-col w-64 bg-primary text-white h-screen fixed shadow-xl z-20">
            <div className="flex items-center h-16 px-6 border-b border-gray-800">
                <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-full border-2 border-green-400 bg-transparent flex items-center justify-center">
                        <span className="font-bold text-green-400 italic">O</span>
                    </div>
                    <h1 className="text-xl font-bold tracking-wider text-white">
                        OLI <span className="font-light text-gray-400">ADMIN</span>
                    </h1>
                </div>
            </div>

            <nav className="flex-1 px-4 py-6 space-y-1">
                {navigation.map((item) => {
                    // Check if active (starts with href to handle sub-routes like /users/123)
                    const isActive = item.href === '/'
                        ? location.pathname === '/'
                        : location.pathname.startsWith(item.href);

                    return (
                        <Link
                            key={item.name}
                            to={item.href}
                            className={classNames(
                                isActive
                                    ? 'bg-gray-800 text-white border-l-4 border-blue-500'
                                    : 'text-gray-400 hover:bg-gray-800 hover:text-white',
                                'group flex items-center px-4 py-3 text-sm font-medium rounded-r-md transition-all duration-200 cursor-pointer relative z-30'
                            )}
                        >
                            <item.icon
                                className={classNames(
                                    isActive ? 'text-blue-500' : 'text-gray-500 group-hover:text-gray-300',
                                    'mr-3 flex-shrink-0 h-5 w-5'
                                )}
                                aria-hidden="true"
                            />
                            {item.name}
                        </Link>
                    );
                })}
            </nav>

            <div className="p-6 border-t border-gray-800">
                <button className="flex items-center text-sm text-gray-500 hover:text-white transition-colors">
                    <span className="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
                    Système Opérationnel
                </button>
            </div>
        </div>
    );
}
