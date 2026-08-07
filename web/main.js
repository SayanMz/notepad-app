/**
 INFINITE SCROLLER: GPU-Accelerated & User-Interactive
 */
document.addEventListener('DOMContentLoaded', () => {
    const gallery = document.getElementById('gallery');
    if (!gallery) return;

    // 1. Double the set for seamless looping
    const content = gallery.innerHTML;
    gallery.innerHTML = content + content;

    let scrollSpeed = 0.5;
    let isPaused = false;
    let isDragging = false;
    let startX, scrollLeft;

    // 2. The Animation Core (Handles Sub-Pixel motion)
    let currentScroll = 0;
    function step() {
        if (!isPaused && !isDragging) {
            currentScroll += scrollSpeed;

            // Reset point: when first half is fully scrolled
            if (currentScroll >= gallery.scrollWidth / 2) {
                currentScroll = 0;
            }
            gallery.scrollLeft = currentScroll;
        } else {
            // Sync tracker with user interaction
            currentScroll = gallery.scrollLeft;
        }
        window.requestAnimationFrame(step);
    }

    // Waiting for images to load to get accurate scrollWidth
    window.addEventListener('load', () => {
        currentScroll = 0;
        step();
    });

    // 3. INTERACTION: Pause & Manual Scroll
    gallery.addEventListener('mouseenter', () => isPaused = true);
    gallery.addEventListener('mouseleave', () => {
        if(!isDragging) isPaused = false;
    });

    // Convert Wheel to Horizontal (Native & Consistent)
    gallery.addEventListener('wheel', (e) => {
        gallery.scrollLeft += e.deltaY;
        currentScroll = gallery.scrollLeft;
        e.preventDefault();
    }, { passive: false });

    // 4. INTERACTION: Mouse Drag
    gallery.addEventListener('mousedown', (e) => {
        isDragging = true;
        gallery.style.cursor = 'grabbing';
        startX = e.pageX - gallery.offsetLeft;
        scrollLeft = gallery.scrollLeft;
    });

    window.addEventListener('mouseup', () => {
        isDragging = false;
        isPaused = false;
        gallery.style.cursor = 'grab';
    });

    gallery.addEventListener('mousemove', (e) => {
        if (!isDragging) return;
        e.preventDefault();
        const x = e.pageX - gallery.offsetLeft;
        const walk = (x - startX) * 2;
        gallery.scrollLeft = scrollLeft - walk;
        currentScroll = gallery.scrollLeft;
    });
});
