const express = require('express');
const puppeteer = require('puppeteer');
const app = express();

app.use(express.json());

const STATE = {
    monitoring: false,
    loggedIn: false,
    browser: null,
    page: null,
    filters: {
        minMoney: 8,
        maxMiles: 5,
        maxItems: 20,
        autoAccept: false
    },
    stats: {
        checked: 0,
        found: 0,
        accepted: 0,
        rejected: 0
    }
};

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
    
    console.log('⚙️ Filters updated:', STATE.filters);
    res.json({ filters: STATE.filters });
});

async function startMonitoring() {
    try {
        console.log('🚀 Starting Spark Monitor...');
        
        STATE.browser = await puppeteer.launch({
            executablePath: '/usr/bin/google-chrome-stable',
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage'
            ]
        });
        
        STATE.page = await STATE.browser.newPage();
        STATE.page.setDefaultTimeout(15000);
        
        await STATE.page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
        
        console.log('✅ Spark Monitor ready - waiting for batches');
        
        while (STATE.monitoring) {
            try {
                await randomDelay(2000, 3000);
                STATE.stats.checked++;
            } catch (err) {
                console.error('❌ Error:', err.message);
                await randomDelay(5000, 8000);
            }
        }
        
        if (STATE.browser) await STATE.browser.close();
        STATE.browser = null;
        
    } catch (err) {
        console.error('❌ Monitoring error:', err.message);
        STATE.monitoring = false;
    }
}

function randomDelay(min, max) {
    const delay = Math.random() * (max - min) + min;
    return new Promise(resolve => setTimeout(resolve, delay));
}

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
    console.log(`🚀 Spark Monitor V1 running on port ${PORT}`);
    console.log(`✅ Ready to monitor Spark batches`);
});

process.on('SIGTERM', async () => {
    console.log('Shutting down...');
    if (STATE.browser) await STATE.browser.close();
    process.exit(0);
});
