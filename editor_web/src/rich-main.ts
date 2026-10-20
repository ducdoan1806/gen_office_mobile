import { installBrowserHost } from './platform/browser-host';
import { installMobileHost } from './platform/mobile-host';
import './rich-host.css';
const host = installBrowserHost();
if (new URLSearchParams(location.search).get('mobile') === '1') installMobileHost(host);
void import('../vendor/docs/renderer/main');
