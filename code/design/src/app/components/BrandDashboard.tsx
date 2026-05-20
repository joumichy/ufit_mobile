import { ArrowLeft, Package, Truck, Download, DollarSign } from 'lucide-react';

const orders = [
  { id: '#UFT-2847', customer: 'Marie D.', items: 2, total: '234€', status: 'pending', date: '20 Mai 2026' },
  { id: '#UFT-2846', customer: 'Lucas M.', items: 1, total: '145€', status: 'shipped', date: '19 Mai 2026' },
  { id: '#UFT-2845', customer: 'Emma R.', items: 3, total: '389€', status: 'delivered', date: '18 Mai 2026' },
  { id: '#UFT-2844', customer: 'Sophie B.', items: 2, total: '210€', status: 'shipped', date: '17 Mai 2026' },
];

const statusColors = {
  pending: 'bg-amber-100 text-amber-800',
  shipped: 'bg-blue-100 text-blue-800',
  delivered: 'bg-emerald-100 text-emerald-800',
};

const statusLabels = {
  pending: 'À expédier',
  shipped: 'Expédié',
  delivered: 'Livré',
};

interface BrandDashboardProps {
  onBack: () => void;
}

export function BrandDashboard({ onBack }: BrandDashboardProps) {
  return (
    <div className="pb-20 min-h-screen bg-white">
      <div className="sticky top-0 z-10 bg-white/95 backdrop-blur-sm border-b border-border">
        <div className="flex items-center px-6 py-4">
          <button onClick={onBack} className="p-2 -ml-2">
            <ArrowLeft className="w-6 h-6" strokeWidth={1.5} />
          </button>
          <h2 className="ml-3">Brand Dashboard</h2>
        </div>
      </div>

      <div className="px-6 py-6 space-y-6">
        <div>
          <h1 className="text-2xl mb-1">Atelier Minimal</h1>
          <p className="text-sm text-muted-foreground">Independent Fashion Brand</p>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-secondary rounded-xl p-4 space-y-1">
            <Package className="w-5 h-5 text-muted-foreground mb-2" strokeWidth={1.5} />
            <p className="text-2xl">24</p>
            <p className="text-xs text-muted-foreground">Pending Orders</p>
          </div>
          <div className="bg-secondary rounded-xl p-4 space-y-1">
            <DollarSign className="w-5 h-5 text-muted-foreground mb-2" strokeWidth={1.5} />
            <p className="text-2xl">8,942€</p>
            <p className="text-xs text-muted-foreground">This Month</p>
          </div>
        </div>

        <div className="bg-secondary rounded-xl p-5 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-sm">Total Revenue (Mai)</span>
            <span className="text-xl">8,942€</span>
          </div>
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">Commission UFit (8%)</span>
            <span className="text-muted-foreground">-715€</span>
          </div>
          <div className="border-t border-white pt-3 flex items-center justify-between">
            <span>Net Revenue</span>
            <span className="text-xl">8,227€</span>
          </div>
        </div>

        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg">Recent Orders</h2>
            <button className="text-sm text-muted-foreground">View all</button>
          </div>

          <div className="space-y-3">
            {orders.map((order) => (
              <div key={order.id} className="bg-secondary rounded-xl p-4 space-y-3">
                <div className="flex items-start justify-between">
                  <div className="space-y-1">
                    <p className="text-sm">{order.id}</p>
                    <p className="text-xs text-muted-foreground">{order.customer} · {order.items} items</p>
                    <p className="text-xs text-muted-foreground">{order.date}</p>
                  </div>
                  <div className="text-right space-y-2">
                    <p>{order.total}</p>
                    <span className={`inline-block px-3 py-1 rounded-full text-[10px] ${statusColors[order.status as keyof typeof statusColors]}`}>
                      {statusLabels[order.status as keyof typeof statusLabels]}
                    </span>
                  </div>
                </div>

                {order.status === 'pending' && (
                  <div className="flex gap-2 pt-2">
                    <button className="flex-1 bg-primary text-primary-foreground rounded-lg py-2.5 text-sm flex items-center justify-center gap-2">
                      <Truck className="w-4 h-4" strokeWidth={1.5} />
                      Ship Order
                    </button>
                    <button className="px-4 bg-white border border-border rounded-lg flex items-center justify-center">
                      <Download className="w-4 h-4" strokeWidth={1.5} />
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
