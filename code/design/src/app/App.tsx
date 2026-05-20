import { useState } from 'react';
import { HomeFeed } from './components/HomeFeed';
import { OutfitDetail } from './components/OutfitDetail';
import { CreatorProfile } from './components/CreatorProfile';
import { BrandDashboard } from './components/BrandDashboard';
import { Onboarding } from './components/Onboarding';
import { BottomNav } from './components/BottomNav';

export default function App() {
  const [showOnboarding, setShowOnboarding] = useState(true);
  const [activeTab, setActiveTab] = useState('feed');
  const [activeView, setActiveView] = useState<'feed' | 'outfit' | 'creator' | 'brand'>('feed');

  if (showOnboarding) {
    return <Onboarding onComplete={() => setShowOnboarding(false)} />;
  }

  const renderContent = () => {
    switch (activeView) {
      case 'outfit':
        return <OutfitDetail onBack={() => setActiveView('feed')} />;
      case 'creator':
        return <CreatorProfile onBack={() => setActiveView('feed')} />;
      case 'brand':
        return <BrandDashboard onBack={() => setActiveView('feed')} />;
      default:
        return (
          <HomeFeed
            onOutfitClick={() => setActiveView('outfit')}
            onCreatorClick={() => setActiveView('creator')}
          />
        );
    }
  };

  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    if (tab === 'feed') {
      setActiveView('feed');
    } else if (tab === 'orders') {
      setActiveView('brand');
    } else if (tab === 'profile') {
      setActiveView('creator');
    }
  };

  return (
    <div className="min-h-screen bg-white max-w-[428px] mx-auto relative">
      {renderContent()}
      <BottomNav activeTab={activeTab} onTabChange={handleTabChange} />
    </div>
  );
}