/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                primary: '#0B1727', // Dark Navy de la maquette
                secondary: '#2563EB', // Blue 600
                success: '#10B981', // Green 500
                danger: '#EF4444', // Red 500
            }
        },
    },
    plugins: [],
}
