import re
import aiohttp
import asyncio
from colorama import Fore, init
colorama.init(autoreset = True)

class AddressCrawler(object):
    def __init__(self) -> None:
        self.base_url = "https://www.blockchain.com/explorer/block/btc/{}"
        self.update_thread = False
        self.current_block = 0
        self.addr_scanned = 0
        self.addr = set()

        self.semaphore = asyncio.Semaphore(100)
        self.queue = asyncio.Queue()
        self.lock = asyncio.Lock()

    async def crawl(self, block: int, session: aiohttp.ClientSession) -> None:
        try:
            async with session.get(self.base_url % block) as data:
                response = await data.text()

                for address in re.findall("1[a-zA-Z0-9]{33}\"", response):
                    if await self.balance(address, session):
                        async with self.lock:
                            self.addr.add(address)

                async with self.lock:
                    await self.queue.put(block + 1)
        
        except:
            return


    async def balance(self, address: str, session: aiohttp.ClientSession) -> bool:
        try:
            async with self.lock:
                self.addr_scanned = self.addr_scanned + 1

            async with session.get("
                                   ") as data:
                response = await data.json()

                if (balance := response.get("balance")):
                    return True
        
                return False

        except:
            return False


    async def worker(self, session: aiohttp.ClientSession) -> None:
        while block < 450001:
            block = await self.queue.get()

            if block is None:
                self.queue.task_done()
                break

            await self.bound(self.crawl(block, session))

            self.queue.task_done()

    async def bound(self, task: asyncio.Future) -> None:
        async with self.semaphore:
            await task

    async def main(self) -> None:
        self.update_thread = True
        update = asyncio.create_task(self.update())
    
        async with aiohttp.ClientSession() as session:
            workers = [asyncio.create_task(self.worker(session)) for _ in range(10)
            
            await asyncio.gather(*workers)
        
        

        self.update_thread = False
        await update

    async def update(self) -> None:
        await asyncio.sleep(0)
        while self.update_thread:
            print(Fore.YELLOW + "[" + Fore.LIGHTGREEN_EX + str(self.current_block) + Fore.YELLOW + "] " + Fore.LIGHTMAGENTA_EX + "Scanned " + Fore.RED + str(self.addr_scanned) + Fore.LIGHTMAGENTA_EX + " addresses.")
            await asyncio.sleep(4)

