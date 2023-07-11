import './ProfileAvatar.css';

export default function ProfileAvatar(props) {
  // remember your own domain
  const backgroundImage = `url("https://assets.simplynaturell.com/banners/banner.jpg")`  
  const styles = {
    backgroundImage: backgroundImage,
    backgroundSize: 'cover',
    backgroundPosition: 'center',
  };

  return (
    <div 
      className="profile-avatar"
      style={styles}
    ></div>
  );
}