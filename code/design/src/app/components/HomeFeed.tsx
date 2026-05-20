import { Heart, MessageCircle, ShoppingBag, Shirt, Footprints, Watch, Glasses } from 'lucide-react';
import { useState } from 'react';

const outfits = [
  {
    id: 1,
    image: 'https://images.unsplash.com/photo-1768825197238-629b1ae2dc18?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtaW5pbWFsaXN0JTIwZmFzaGlvbiUyMG91dGZpdCUyMHN0cmVldCUyMHN0eWxlfGVufDF8fHx8MTc3OTI5MDE1OXww&ixlib=rb-4.1.0&q=80&w=1080',
    creator: 'Sofia Laurent',
    creatorAvatar: 'SL',
    price: '289€',
    likes: 342,
    comments: 28,
    title: 'Urban Minimalism',
    products: [
      { icon: Shirt, name: 'Oversized Shirt' },
      { icon: Shirt, name: 'Wide Pants' },
      { icon: ShoppingBag, name: 'Leather Bag' },
      { icon: Footprints, name: 'Sandals' },
      { icon: Glasses, name: 'Sunglasses' },
    ],
  },
  {
    id: 2,
    image: 'https://images.unsplash.com/photo-1763499389975-f27898185f17?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwzfHxtaW5pbWFsaXN0JTIwZmFzaGlvbiUyMG91dGZpdCUyMHN0cmVldCUyMHN0eWxlfGVufDF8fHx8MTc3OTI5MDE1OXww&ixlib=rb-4.1.0&q=80&w=1080',
    creator: 'Emma Stone',
    creatorAvatar: 'ES',
    price: '198€',
    likes: 287,
    comments: 15,
    title: 'Cozy Essentials',
    products: [
      { icon: Shirt, name: 'Sweater' },
      { icon: Shirt, name: 'Jeans' },
      { icon: Footprints, name: 'Sneakers' },
    ],
  },
  {
    id: 3,
    image: 'https://images.unsplash.com/photo-1746458258548-5e5bd7225c9c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHw1fHxtaW5pbWFsaXN0JTIwZmFzaGlvbiUyMG91dGZpdCUyMHN0cmVldCUyMHN0eWxlfGVufDF8fHx8MTc3OTI5MDE1OXww&ixlib=rb-4.1.0&q=80&w=1080',
    creator: 'Lena M.',
    creatorAvatar: 'LM',
    price: '245€',
    likes: 412,
    comments: 34,
    title: 'Professional Edit',
    products: [
      { icon: Shirt, name: 'Blazer' },
      { icon: Shirt, name: 'Trousers' },
      { icon: ShoppingBag, name: 'Laptop Bag' },
      { icon: Footprints, name: 'Heels' },
      { icon: Watch, name: 'Watch' },
    ],
  },
];

interface HomeFeedProps {
  onOutfitClick: (id: number) => void;
  onCreatorClick: () => void;
}

export function HomeFeed({ onOutfitClick, onCreatorClick }: HomeFeedProps) {
  const [likedOutfits, setLikedOutfits] = useState<number[]>([]);

  const handleLike = (outfitId: number) => {
    if (likedOutfits.includes(outfitId)) {
      setLikedOutfits(likedOutfits.filter(id => id !== outfitId));
    } else {
      setLikedOutfits([...likedOutfits, outfitId]);
    }
  };

  return (
    <div className="h-screen overflow-y-scroll snap-y snap-mandatory scrollbar-hide pb-20">
      {outfits.map((outfit) => {
        const isLiked = likedOutfits.includes(outfit.id);

        return (
          <div key={outfit.id} className="relative w-full h-screen snap-start shrink-0 bg-black">
            <img
              src={outfit.image}
              alt={outfit.title}
              className="w-full h-full object-cover"
            />

            <div className="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/60"></div>

            <div className="absolute right-4 bottom-24 flex flex-col items-center gap-6">
              <div className="max-h-[200px] overflow-y-auto scrollbar-hide flex flex-col gap-3">
                {outfit.products.map((product, index) => {
                  const ProductIcon = product.icon;
                  return (
                    <button
                      key={index}
                      className="w-12 h-12 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center shrink-0"
                    >
                      <ProductIcon className="w-6 h-6 text-white" strokeWidth={1.5} />
                    </button>
                  );
                })}
              </div>

              <button
                onClick={() => handleLike(outfit.id)}
                className="flex flex-col items-center gap-1"
              >
                <div className="w-12 h-12 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center">
                  <Heart
                    className={`w-7 h-7 ${isLiked ? 'fill-white text-white' : 'text-white'}`}
                    strokeWidth={1.5}
                  />
                </div>
                <span className="text-white text-xs">
                  {isLiked ? outfit.likes + 1 : outfit.likes}
                </span>
              </button>

              <button className="flex flex-col items-center gap-1">
                <div className="w-12 h-12 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center">
                  <MessageCircle className="w-7 h-7 text-white" strokeWidth={1.5} />
                </div>
                <span className="text-white text-xs">{outfit.comments}</span>
              </button>
            </div>

            <div className="absolute bottom-24 left-6 right-24 text-white space-y-3">
              <button
                onClick={onCreatorClick}
                className="flex items-center gap-3 text-left"
              >
                <div className="w-11 h-11 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center border-2 border-white">
                  <span className="text-sm">{outfit.creatorAvatar}</span>
                </div>
                <div>
                  <p className="text-sm">{outfit.creator}</p>
                  <p className="text-xs text-white/80">Creator</p>
                </div>
              </button>

              <div>
                <h3 className="text-lg">{outfit.title}</h3>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
