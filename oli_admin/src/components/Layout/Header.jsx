import { Fragment } from 'react';
import { Menu, Transition } from '@headlessui/react';
import {
    BellIcon,
    Bars3Icon,
    MagnifyingGlassIcon,
    ChatBubbleLeftRightIcon
} from '@heroicons/react/24/outline';
import { useNavigate } from 'react-router-dom';
import { removeToken, getUser } from '../../utils/auth';
import { getImageUrl } from '../../utils/image';

export default function Header() {
    const navigate = useNavigate();
    const user = getUser();

    const handleLogout = () => {
        removeToken();
        navigate('/login');
    };

    return (
        <header className="bg-white h-16 flex items-center justify-between px-6 border-b border-gray-200 sticky top-0 z-10">
            {/* Left: Mobile Menu Trigger & Search */}
            <div className="flex items-center flex-1 gap-6">
                <button className="text-gray-400 hover:text-gray-600 lg:hidden">
                    <Bars3Icon className="h-6 w-6" />
                </button>

                {/* Search Bar */}
                <div className="relative w-full max-w-md hidden md:block">
                    <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                        <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" aria-hidden="true" />
                    </div>
                    <input
                        type="text"
                        name="search"
                        id="search"
                        className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-gray-50 placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                        placeholder="Rechercher (ex: +243 82 000...)"
                    />
                </div>
            </div>

            {/* Right: Actions & Profile */}
            <div className="flex items-center gap-4">
                <button className="p-2 text-gray-400 hover:text-gray-600 transition-colors">
                    <ChatBubbleLeftRightIcon className="h-6 w-6" />
                </button>
                <div className="relative">
                    <button className="p-2 text-gray-400 hover:text-gray-600 transition-colors">
                        <BellIcon className="h-6 w-6" />
                    </button>
                    <span className="absolute top-2 right-2 block h-2 w-2 rounded-full bg-red-500 ring-2 ring-white" />
                </div>

                {/* Profile Dropdown */}
                <Menu as="div" className="relative ml-2">
                    <div>
                        <Menu.Button className="flex items-center text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                            <span className="sr-only">Open user menu</span>
                            <img
                                className="h-8 w-8 rounded-full object-cover border border-gray-200"
                                src={getImageUrl(user?.avatar) || "https://ui-avatars.com/api/?name=Admin+Oli&background=0B1727&color=fff"}
                                alt=""
                                onError={(e) => {
                                    e.target.onerror = null;
                                    e.target.src = "https://ui-avatars.com/api/?name=Admin+Oli&background=0B1727&color=fff";
                                }}
                            />
                        </Menu.Button>
                    </div>
                    <Transition
                        as={Fragment}
                        enter="transition ease-out duration-100"
                        enterFrom="transform opacity-0 scale-95"
                        enterTo="transform opacity-100 scale-100"
                        leave="transition ease-in duration-75"
                        leaveFrom="transform opacity-100 scale-100"
                        leaveTo="transform opacity-0 scale-95"
                    >
                        <Menu.Items className="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg py-1 bg-white ring-1 ring-black ring-opacity-5 focus:outline-none">
                            <Menu.Item>
                                {({ active }) => (
                                    <a
                                        href="#"
                                        className={classNames(active ? 'bg-gray-100' : '', 'block px-4 py-2 text-sm text-gray-700')}
                                    >
                                        Mon Profil
                                    </a>
                                )}
                            </Menu.Item>
                            <Menu.Item>
                                {({ active }) => (
                                    <a
                                        href="#"
                                        className={classNames(active ? 'bg-gray-100' : '', 'block px-4 py-2 text-sm text-gray-700')}
                                    >
                                        Paramètres
                                    </a>
                                )}
                            </Menu.Item>
                            <Menu.Item>
                                {({ active }) => (
                                    <button
                                        onClick={handleLogout}
                                        className={classNames(active ? 'bg-gray-100' : '', 'block w-full text-left px-4 py-2 text-sm text-red-600')}
                                    >
                                        Déconnexion
                                    </button>
                                )}
                            </Menu.Item>
                        </Menu.Items>
                    </Transition>
                </Menu>
            </div>
        </header>
    );
}

function classNames(...classes) {
    return classes.filter(Boolean).join(' ')
}
