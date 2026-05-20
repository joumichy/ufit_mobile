import { ArrowLeft, Heart, Share2 } from 'lucide-react';

const outfitPieces = [
  { id: 1, name: 'Oversized Linen Shirt', brand: 'Atelier Minimal', price: '89€', sizes: ['XS', 'S', 'M', 'L'] },
  { id: 2, name: 'High-Waisted Wide Pants', brand: 'Maison Blanche', price: '120€', sizes: ['36', '38', '40', '42'] },
  { id: 3, name: 'Leather Crossbody Bag', brand: 'Studio Craft', price: '145€', sizes: ['One Size'] },
  { id: 4, name: 'Minimalist Sandals', brand: 'Bare Studio', price: '95€', sizes: ['37', '38', '39', '40'] },
];

interface OutfitDetailProps {
  onBack: () => void;
}

export function OutfitDetail({ onBack }: OutfitDetailProps) {
  return (
    <div className="pb-20 min-h-screen bg-white">
      <div className="sticky top-0 z-10 bg-white/95 backdrop-blur-sm border-b border-border">
        <div className="flex items-center justify-between px-6 py-4">
          <button onClick={onBack} className="p-2 -ml-2">
            <ArrowLeft className="w-6 h-6" strokeWidth={1.5} />
          </button>
          <div className="flex items-center gap-4">
            <button className="p-2">
              <Share2 className="w-6 h-6" strokeWidth={1.5} />
            </button>
            <button className="p-2">
              <Heart className="w-6 h-6" strokeWidth={1.5} />
            </button>
          </div>
        </div>
      </div>

      <div className="aspect-[3/4] bg-secondary">
        <img
          src="https://images.unsplash.com/photo-1768825197238-629b1ae2dc18?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtaW5pbWFsaXN0JTIwZmFzaGlvbiUyMG91dGZpdCUyMHN0cmVldCUyMHN0eWxlfGVufDF8fHx8MTc3OTI5MDE1OXww&ixlib=rb-4.1.0&q=80&w=1080"
          alt="Outfit"
          className="w-full h-full object-cover"
        />
      </div>

      <div className="px-6 py-6 space-y-6">
        <div>
          <h1 className="text-2xl mb-1">Urban Minimalism</h1>
          <p className="text-muted-foreground">By Sofia Laurent</p>
          <p className="text-sm text-muted-foreground mt-2">
            Effortless elegance meets street style. A carefully curated selection of premium pieces from independent European ateliers.
          </p>
        </div>

        <div className="space-y-4">
          <h2 className="text-lg">Complete the Look</h2>

          {outfitPieces.map((piece, index) => (
            <div key={piece.id} className="bg-secondary rounded-xl p-4 space-y-3">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <p className="text-sm text-muted-foreground">#{index + 1}</p>
                  <h3 className="mt-1">{piece.name}</h3>
                  <p className="text-sm text-muted-foreground mt-1">{piece.brand}</p>
                </div>
                <p className="text-lg">{piece.price}</p>
              </div>

              <div className="flex flex-wrap gap-2">
                {piece.sizes.map((size) => (
                  <button
                    key={size}
                    className="px-4 py-2 bg-white border border-border rounded-lg text-sm hover:border-primary transition-colors"
                  >
                    {size}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>

        <div className="bg-secondary rounded-xl p-4 space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-muted-foreground">Subtotal</span>
            <span>449€</span>
          </div>
          <div className="flex items-center justify-between border-t border-border pt-2">
            <span>Total</span>
            <span className="text-xl">449€</span>
          </div>
        </div>

        <button className="w-full bg-primary text-primary-foreground rounded-xl py-4">
          Acheter le look complet
        </button>
      </div>
    </div>
  );
}
