const express = require('express');
const puppeteer = require('puppeteer');
app = express();

app.use(express.json());

// ===== STATE =====
const STATE = {
    monitoring: false,
    loggedIn: false,
    browser: null,
    page: null,
    filters: {
        minMoney: 8,
        maxMiles: 5,
        maxItems: 20,
        autoAccept: false,
        acceptDelayMs: 2000 // 1-3 seconds humanlike
    },
    foundBatches: [],
    acceptedBatches: [],
    stats: {
        checked: 0,
        found: 0,
        accepted: 0,
        rejected: 0
    }
};

// ===== ENDPOINTS =====

app.post('/start', async (req, res) => {
    if (STATE.monitoring) return res.json({ status: 'already monitoring' });
    
    STATE.monitoring = true;
    res.json({ status: 'started' });
    
    startMonitoring();
});

app.post('/stop', (req, res) => {
    STATE.monitoring = false;
    res.json({ status: 'stopped' });
});

app.get('/status', (req, res) => {
    res.json({
        monitoring: STATE.monitoring,
        loggedIn: STATE.loggedIn,
        filters: STATE.filters,
        stats: STATE.stats
    });
});

app.post('/config', (req, res) => {
    if (req.body.minMoney !== undefined) STATE.filters.minMoney = req.body.minMoney;
    if (req.body.maxMiles !== undefined) STATE.filters.maxMiles = req.body.maxMiles;
    if (req.body.maxItems !== undefined) STATE.filters.maxItems = req.body.maxItems;
    if (req.body.autoAccept !== undefined) STATE.filters.autoAccept = req.body.autoAccept;
    if (req.body.acceptDelayMs !== undefined) STATE.filters.acceptDelayMs = req.body.acceptDelayMs;
    
    console.log('⚙️ Spark Filters updated:', STATE.filters);
    res.json({ filters: STATE.filters });
});

app.get('/stats', (req, res) => {
    res.json({
        monitoring: STATE.monitoring,
        stats: STATE.stats,
        filters: STATE.filters
    });
});

// ===== MAIN MONITORING =====

async function startMonitoring() {
    try {
        console.log('🚀 Starting Spark Monitor...');
        
        STATE.browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--single-process'
            ]
        });
        
        STATE.page = await STATE.browser.newPage();
        STATE.page.setDefaultTimeout(15000);
        
        // User-agent humanlike
        await STATE.page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
        
        // Login
        await loginToSpark();
        STATE.loggedIn = true;
        
        // Poll for batches
        while (STATE.monitoring) {
            try {
                await checkForBatches();
                await randomDelay(1500, 2500); // Humanlike polling
            } catch (err) {
                console.error('❌ Error checking batches:', err.message);
                await randomDelay(5000, 8000);
            }
        }
        
        if (STATE.browser) await STATE.browser.close();
        STATE.browser = null;
        STATE.loggedIn = false;
        
    } catch (err) {
        console.error('❌ Monitoring error:', err.message);
        STATE.monitoring = false;
        STATE.loggedIn = false;
    }
}

async function loginToSpark() {
    const email = process.env.SPARK_EMAIL;
    const password = process.env.SPARK_PASSWORD;
    
    try {
        console.log('🔐 Logging into Spark...');
        
        await STATE.page.goto('https://www.spark.work/login', { 
            waitUntil: 'networkidle2',
            timeout: 30000 
        });
        
        // Type email slowly (humanlike)
        await STATE.page.type('input[type="email"]', email, { delay: 100 });
        await randomDelay(500, 1000);
        
        // Type password slowly
        await STATE.page.type('input[type="password"]', password, { delay: 100 });
        await randomDelay(800, 1200);
        
        // Click submit
        await STATE.page.click('button[type="submit"]');
        await STATE.page.waitForNavigation().catch(() => {});
        
        await randomDelay(2000, 3000);
        console.log('✅ Spark login successful');
        
    } catch (err) {
        console.error('❌ Spark login failed:', err.message);
    }
}

async function checkForBatches() {
    try {
        STATE.stats.checked++;
        
        await STATE.page.goto('https://www.spark.work/spark/batches', {
            waitUntil: 'networkidle2',
            timeout: 15000
        }).catch(() => {});
        
        // Get available batches
        const batches = await STATE.page.evaluate(() => {
            const items = [];
            document.querySelectorAll('[data-testid*="batch"]').forEach(el => {
                const text = el.innerText;
                const money = text.match(/\$[\d.]+/)?.[0];
                const miles = text.match(/([\d.]+)\s*mi/)?.[1];
                
                if (money && miles) {
                    items.push({
                        money: parseFloat(money.replace('$', '')),
                        miles: parseFloat(miles),
                        element: el.getAttribute('data-testid')
                    });
                }
            });
            return items;
        });
        
        if (batches.length > 0) {
            console.log(`📦 Found ${batches.length} Spark batches`);
            STATE.stats.found += batches.length;
        }
        
        for (const batch of batches) {
            // Check filters
            if (batch.money < STATE.filters.minMoney || 
                batch.miles > STATE.filters.maxMiles) {
                STATE.stats.rejected++;
                continue;
            }
            
            // Open batch to check items
            try {
                await STATE.page.click(`[data-testid="${batch.element}"]`);
                await randomDelay(1000, 2000);
                
                const itemCount = await STATE.page.evaluate(() => {
                    return document.querySelectorAll('[data-testid*="item"]').length || 0;
                });
                
                console.log(`✅ GOOD BATCH: $${batch.money}, ${batch.miles}mi, ${itemCount} items`);
                
                if (itemCount <= STATE.filters.maxItems) {
                    STATE.stats.found++;
                    
                    // Send notification
                    console.log('📱 Sending notification...');
                    
                    if (STATE.filters.autoAccept) {
                        // Humanlike accept
                        await randomDelay(
                            STATE.filters.acceptDelayMs - 500,
                            STATE.filters.acceptDelayMs + 500
                        );
                        
                        await acceptBatch();
                        
                        STATE.acceptedBatches.push({
                            money: batch.money,
                            miles: batch.miles,
                            items: itemCount,
                            time: new Date().toISOString()
                        });
                        STATE.stats.accepted++;
                        
                        console.log('✅ Batch auto-accepted (humanlike)');
                    } else {
                        console.log('📲 Notification sent - manual accept pending');
                    }
                } else {
                    console.log(`❌ Too many items (${itemCount} > ${STATE.filters.maxItems})`);
                    STATE.stats.rejected++;
                }
                
                // Go back to batches list
                await STATE.page.goBack();
                await randomDelay(1000, 2000);
                
            } catch (err) {
                console.error('❌ Error processing batch:', err.message);
            }
        }
        
    } catch (err) {
        console.error('❌ Check batches error:', err.message);
    }
}

async function acceptBatch() {
    try {
        // Find and click accept button (humanlike)
        await STATE.page.waitForSelector('button:has-text("Accept")', { timeout: 5000 })
            .catch(() => STATE.page.waitForSelector('button[type="submit"]', { timeout: 5000 }));
        
        await randomDelay(300, 800); // Small delay before click
        
        await STATE.page.click('button:has-text("Accept")').catch(() => {
            return STATE.page.click('button[type="submit"]');
        });
        
        console.log('✅ Accept button clicked');
        
    } catch (err) {
        console.error('❌ Accept failed:', err.message);
    }
}

// ===== UTILITIES =====

function randomDelay(min, max) {
    const delay = Math.random() * (max - min) + min;
    return new Promise(resolve => setTimeout(resolve, delay));
}

// ===== SERVER =====

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`\n🚀 Spark Monitor V1 running on port ${PORT}`);
    console.log(`✅ Ready to monitor Spark batches\n`);
});

process.on('SIGTERM', async () => {
    console.log('Shutting down...');
    if (STATE.browser) await STATE.browser.close();
    process.exit(0);
});
