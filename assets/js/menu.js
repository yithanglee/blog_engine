export const MENUS = [
    {
        path: '#', title: 'Admin', icon: null, children: [
            { path: '/admin/staff', title: 'Staff', icon: 'camera-foto-solid' },
            { path: '/admin/role', title: 'Role', icon: 'camera-foto-solid' },

            { path: '/admin/app_route', title: 'Route', icon: 'camera-foto-solid' },
            { path: '/merchants/categories', title: 'Merchant Business Categories', icon: 'camera-foto-solid' },
      
        ]
    },
    {
        path: '#', title: 'Geo', icon: null, children: [
            { path: '/geo/countries', title: 'Country', icon: 'camera-foto-solid' },
            { path: '/geo/states', title: 'States', icon: 'camera-foto-solid' },
            { path: '/geo/pick_up_points', title: 'Pick Up Points', icon: 'camera-foto-solid' },
        ]
    },
    { path: '/announcements', title: 'Announcements', icon: 'book-solid' },
    { path: '/slides', title: 'Slides', icon: 'book-solid' },
    {
        path: '#', title: 'Commission', icon: null, children: [
            { path: '/rewards/summary', title: 'Commission Summary', icon: 'camera-foto-solid' },
            { path: '/rewards/details', title: 'Commission Details', icon: 'camera-foto-solid' },
            { path: '/rewards', title: 'All Commission', icon: 'camera-foto-solid' },
            { path: '/rewards/royalty_users', title: 'Royalty Users', icon: 'camera-foto-solid' },

        ]
    },
    {
        path: '#', title: 'GroupSales', icon: null, children: [
            { path: '/referral_gs_summary', title: 'Referral GS Summary', icon: 'book-solid' },
            { path: '/referral_gs_details', title: 'Referral GS Details', icon: 'book-solid' },

            { path: '/gs_summary', title: 'Placement GS Summary', icon: 'book-solid' },
            { path: '/group_sales_details', title: 'Placement GS Details', icon: 'book-solid' },

        ]
    },
    { path: '/deliveries', title: 'Deliveries', icon: 'book-solid' },
    { path: '/merchants', title: 'Merchants', icon: 'book-solid' },
    { path: '/sales', title: 'Sales', icon: 'book-solid' },
    {
        path: '#', title: 'Stocks', icon: null, children: [
            { path: '/products', title: 'Product', icon: 'book-solid' },
            { path: '/stocks', title: 'Stocks', icon: 'book-solid' },
            { path: '/stock_adjustments', title: 'Stock Adjustments', icon: 'book-solid' },
            { path: '/stocks/summaries', title: 'Stocks Summaries', icon: 'book-solid' },
        ]
    },
    {
        path: '#', title: 'Users', icon: null, children: [

            { path: '/users', title: 'Users', icon: 'book-solid' },
            { path: '/users/placements', title: 'Placements', icon: 'book-solid' }
        ]
    },
    { path: '/ranks', title: 'Rank', icon: 'book-solid' },
    {
        path: '#', title: 'Ewallets', icon: null, children: [
            { path: '/ewallets/withdrawal_batches', title: 'Withdrawal', icon: 'camera-foto-solid' },
            { path: '/ewallets/merchant_withdrawals', title: 'Merchant Withdrawal', icon: 'camera-foto-solid' },
            { path: '/ewallets', title: 'Ewallets', icon: 'book-solid' },
            { path: '/ewallets/transfers', title: 'Transfers', icon: 'camera-foto-solid' },
            { path: '/ewallets/register_points', title: 'Register Points', icon: 'camera-foto-solid' },

        ]
    },


];